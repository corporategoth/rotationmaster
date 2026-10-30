-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared TBC Hunter blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.hunter.ranged.simulator and rm.tbc.hunter.ranged.wowhead. A content change
-- needs a block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research tbc/hunter.md.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function mana(op,n)return{type='MANAPCT',unit='player',operator=op,value=n}end
local standing=BuiltinConditions.negate({type='MOVING'})
local unmarked=BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1130,anyrank=true})
local stingless=BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}))
local healthy={type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.3}
-- Elite or boss target in combat: worth the major cooldowns.
local worth=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite')))
-- Boundaries every variant shares: casts/channels, no target, melee range, the pull, Auto Shot,
-- Hunter's Mark and the multi-target branch.
assert(addon:RegisterDefaultBlock({
 id='tbc.hunter.opening',revision=4,families={'tbc'},class='HUNTER',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))},
 {id='melee',type='branch',conditions={type='BEYOND_MELEE',unit='target'},onTrue={},onFalse={
  BuiltinConditions.spell('raptor-strike',2973,BuiltinConditions.negate({type='SPELL_ACTIVE',spell=2973,ranked=false})),
  BuiltinConditions.spell('mongoose-bite',1495),
  BuiltinConditions.spell('counterattack',19306),
  {id='melee-stop',type='stop',suppress_attack=false,conditions={}},
 }},
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-mark',1130,unmarked),
  BuiltinConditions.spell('pull-aimed-shot',19434,standing),
  {id='pull-auto-shot',type='spell',action=75,ranked=true,conditions=BuiltinConditions.negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true})},
  {id='pull-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 {id='auto-shot',type='spell',action=75,ranked=true,conditions=BuiltinConditions.all(BuiltinConditions.negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true}),standing)},
 BuiltinConditions.spell('mark',1130,BuiltinConditions.all(unmarked,healthy)),
 -- Three or more enemies fighting you: Multi-Shot whenever it is ready, whatever the mana.
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={BuiltinConditions.spell('aoe-multi-shot',2643)}},
}}))
-- Before Steady Shot: keep your own sting up, then spend mana only while there is plenty, then let Auto Shot and the pet work.
assert(addon:RegisterDefaultBlock({
 id='tbc.hunter.leveling',revision=2,families={'tbc'},class='HUNTER',steps={
 BuiltinConditions.spell('serpent-sting',1978,BuiltinConditions.all(stingless,healthy)),
 BuiltinConditions.spell('aimed-shot',19434,mana('GREATERTHAN',.5)),
 BuiltinConditions.spell('multi-shot',2643,mana('GREATERTHAN',.4)),
 BuiltinConditions.spell('arcane-shot',3044,mana('GREATERTHAN',.5)),
 {id='wait',type='stop',suppress_attack=true,conditions={}},
}}))
-- Independent reminders: Monkey before Hawk is known, Trueshot Aura, pet care, Kill Command,
-- major cooldowns on elites and bosses, and Silencing Shot as an interrupt.
assert(addon:RegisterDefaultBlock({
 id='tbc.hunter.upkeep',revision=1,families={'tbc'},class='HUNTER',steps={
 BuiltinConditions.spell('monkey',13163,BuiltinConditions.all(BuiltinConditions.negate({type='SPELL_KNOWN',spell=13165}),BuiltinConditions.negate({type='BUFF',unit='player',spell=13163,anyrank=true}))),
 BuiltinConditions.spell('trueshot-aura',19506,BuiltinConditions.negate({type='BUFF',unit='player',spell=19506,anyrank=true})),
 BuiltinConditions.spell('call-pet',883,BuiltinConditions.negate({type='PET'})),
 BuiltinConditions.spell('revive-pet',982,{type='DEAD',unit='pet'}),
 BuiltinConditions.spell('mend-pet',136,BuiltinConditions.all({type='PET'},{type='HEALTHPCT',unit='pet',operator='LESSTHAN',value=.5},BuiltinConditions.negate({type='BUFF',unit='pet',spell=136,anyrank=true}))),
 BuiltinConditions.spell('kill-command',34026,BuiltinConditions.combat()),
 BuiltinConditions.spell('bestial-wrath',19574,worth),
 BuiltinConditions.spell('rapid-fire',3045,BuiltinConditions.all(worth,BuiltinConditions.negate({type='BUFF',unit='player',spell=3045,anyrank=true}))),
 BuiltinConditions.spell('readiness',23989,BuiltinConditions.all(worth,{type='SPELL_COOLDOWN',spell=3045,ranked=false,operator='GREATERTHAN',value=60},BuiltinConditions.negate({type='BUFF',unit='player',spell=3045,anyrank=true}))),
 BuiltinConditions.spell('silencing-shot',34490,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
}}))
