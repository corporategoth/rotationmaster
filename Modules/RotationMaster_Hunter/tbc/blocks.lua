-- Shared TBC Hunter blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.hunter.ranged.wowsims and rm.tbc.hunter.ranged.wowhead. A content change
-- needs a block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research tbc/hunter.md.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function mana(op,n)return{type='MANAPCT',unit='player',operator=op,value=n}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local standing=negate({type='MOVING'})
local unmarked=negate({type='DEBUFF',unit='target',spell=1130,anyrank=true})
local stingless=all(negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}))
local healthy={type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.3}
-- Elite or boss target in combat: worth the major cooldowns.
local worth=all(combat(),any(classified('worldboss'),classified('elite')))
-- Boundaries every variant shares: casts/channels, no target, melee range, the pull, Auto Shot,
-- Hunter's Mark and the multi-target branch.
assert(addon:RegisterDefaultBlock({
 id='tbc.hunter.opening',revision=2,families={'tbc'},class='HUNTER',steps={
 {id='manual',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
 {id='melee',type='branch',conditions={type='BEYOND_MELEE',unit='target'},onTrue={},onFalse={
  spell('raptor-strike',2973,negate({type='SPELL_ACTIVE',spell=2973,ranked=false})),
  spell('mongoose-bite',1495),
  spell('counterattack',19306),
  {id='melee-stop',type='none',suppress_attack=false,conditions={}},
 }},
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('pull-mark',1130,unmarked),
  spell('pull-aimed-shot',19434,standing),
  {id='pull-auto-shot',type='spell',action=75,ranked=true,conditions=negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true})},
  {id='pull-stop',type='none',suppress_attack=true,conditions={}},
 }},
 {id='auto-shot',type='spell',action=75,ranked=true,conditions=all(negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true}),standing)},
 spell('mark',1130,all(unmarked,healthy)),
 -- Three or more enemies fighting you: Multi-Shot whenever it is ready, whatever the mana.
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={spell('aoe-multi-shot',2643)}},
}}))
-- Before Steady Shot: keep your own sting up, then spend mana only while there is plenty, then let Auto Shot and the pet work.
assert(addon:RegisterDefaultBlock({
 id='tbc.hunter.leveling',revision=1,families={'tbc'},class='HUNTER',steps={
 spell('serpent-sting',1978,all(stingless,healthy)),
 spell('aimed-shot',19434,mana('GREATERTHAN',.5)),
 spell('multi-shot',2643,mana('GREATERTHAN',.4)),
 spell('arcane-shot',3044,mana('GREATERTHAN',.5)),
 {id='wait',type='none',suppress_attack=true,conditions={}},
}}))
-- Independent reminders: Monkey before Hawk is known, Trueshot Aura, pet care, Kill Command,
-- major cooldowns on elites and bosses, and Silencing Shot as an interrupt.
assert(addon:RegisterDefaultBlock({
 id='tbc.hunter.upkeep',revision=1,families={'tbc'},class='HUNTER',steps={
 spell('monkey',13163,all(negate({type='SPELL_KNOWN',spell=13165}),negate({type='BUFF',unit='player',spell=13163,anyrank=true}))),
 spell('trueshot-aura',19506,negate({type='BUFF',unit='player',spell=19506,anyrank=true})),
 spell('call-pet',883,negate({type='PET'})),
 spell('revive-pet',982,{type='DEAD',unit='pet'}),
 spell('mend-pet',136,all({type='PET'},{type='HEALTHPCT',unit='pet',operator='LESSTHAN',value=.5},negate({type='BUFF',unit='pet',spell=136,anyrank=true}))),
 spell('kill-command',34026,combat()),
 spell('bestial-wrath',19574,worth),
 spell('rapid-fire',3045,all(worth,negate({type='BUFF',unit='player',spell=3045,anyrank=true}))),
 spell('readiness',23989,all(worth,{type='SPELL_COOLDOWN',spell=3045,ranked=false,operator='GREATERTHAN',value=60},negate({type='BUFF',unit='player',spell=3045,anyrank=true}))),
 spell('silencing-shot',34490,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
}}))
