-- Shared TBC Rogue blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.rogue.dps.wowsims and rm.tbc.rogue.dps.wowhead. A content change needs a
-- block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research tbc/rogue.md.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function item(id,items,conditions)return{id=id,type='item',action=items,conditions=conditions}end
local behind=negate({type='ISSAME',unit='targettarget',otherunit='player'})
local sliced={type='BUFF',unit='player',spell=5171,anyrank=true,ownbuff=true}
-- Elite or boss target, or a second enemy fighting you: worth Blade Flurry / Adrenaline Rush.
local worth=any(classified('worldboss'),classified('elite'),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2})
local instant={21927,8928,8927,8926,6950,6949,6947}
local offhand={22054,22053,20844,8985,8984,2893,2892}
for _,id in ipairs(instant)do offhand[#offhand+1]=id end
-- Boundaries: manual casts/channels, no attackable target, the stealth opener, then Riposte.
assert(addon:RegisterDefaultBlock({
 id='tbc.rogue.opening',revision=1,families={'tbc'},class='ROGUE',steps={
 {id='manual',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 {id='stealth',type='branch',conditions={type='STEALTHED'},onFalse={},onTrue={
  spell('premeditation',14183),
  {id='opener',type='branch',conditions={type='GROUP'},onTrue={spell('group-garrote',703)},onFalse={spell('cheap-shot',1833)}},
  spell('ambush',8676,behind),
  spell('garrote',703),
  spell('stealth-sinister',1752),
  {id='stealth-stop',type='none',suppress_attack=true,conditions={}},
 }},
 spell('riposte',14251),
}}))
-- Independent reminders: poisons on each weapon, Kick, and the cooldowns the sources pair.
assert(addon:RegisterDefaultBlock({
 id='tbc.rogue.upkeep',revision=1,families={'tbc'},class='ROGUE',steps={
 item('mainhand-poison',instant,negate({type='WEAPON'})),
 item('offhand-poison',offhand,all({type='SWING_TIME',offhand=true,operator='GREATERTHAN',value=0},negate({type='WEAPON',offhand=true}))),
 spell('kick',1766,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('blade-flurry',13877,all(combat(),sliced,worth)),
 spell('adrenaline-rush',13750,all(combat(),sliced,worth)),
 spell('cold-blood',14177,all(combat(),{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=4})),
 spell('evasion',5277,all(combat(),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.5},{type='ISSAME',unit='targettarget',otherunit='player'})),
}}))
-- Builders, decided by what is known: Shiv saves a full Deadly Poison stack, Mutilate or Backstab
-- when the target is not attacking you, otherwise Hemorrhage or Sinister Strike.
assert(addon:RegisterDefaultBlock({
 id='tbc.rogue.builders',revision=1,families={'tbc'},class='ROGUE',steps={
 spell('shiv',5938,all({type='DEBUFF_STACKS',unit='target',spell=2818,anyrank=true,owndebuff=true,operator='GREATERTHANOREQUALS',value=5},
  {type='DEBUFF_REMAIN',unit='target',spell=2818,anyrank=true,owndebuff=true,operator='LESSTHAN',value=2})),
 spell('ghostly-strike',14278),
 spell('hemorrhage',16511),
 {id='behind',type='branch',conditions=behind,onFalse={},onTrue={
  spell('mutilate',1329),
  spell('backstab',53),
 }},
 spell('sinister',1752),
}}))
