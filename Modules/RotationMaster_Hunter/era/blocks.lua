-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Classic Era Hunter blocks (Built In composition; authoring-time only).
-- Consumers: rm.era.hunter.ranged, rm.era.hunter.ranged.icyveins, rm.era.hunter.ranged.simulator,
-- rm.sod.hunter.ranged and rm.sod.hunter.melee (which use sod.hunter.upkeep). A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research era/hunter.md.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function mana(op,n)return{type='MANAPCT',unit='player',operator=op,value=n}end
local function instance(kind)return{type='INSTANCE',value=kind}end
local function stop(id,attack)return{id=id,type='stop',suppress_attack=not attack,conditions={}}end
local function afterAuto(window)return{type='SPELL_HISTORY_TIME',spell=75,ranked=true,operator='LESSTHANOREQUALS',value=window}end
local standing=BuiltinConditions.negate({type='MOVING'})
local unmarked=BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1130,anyrank=true})
local stingless=BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),
 BuiltinConditions.negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=3034,anyrank=true,owndebuff=true}))
local lives=BuiltinConditions.any({type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.3},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=8})
local attacked={type='ISSAME',unit='targettarget',otherunit='player'}
local loneWolf={type='RUNE_ENGRAVED',spell=415370}
-- Casts and channels (Aimed Shot, Steady Shot, Volley, Mend Pet) and a missing target end advice.
assert(addon:RegisterDefaultBlock({id='era.hunter.boundaries',revision=3,families={'era'},class='HUNTER',steps={
 {id='manual',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))},
}}))
-- Vanilla dead zone: inside melee range only the melee buttons work.
assert(addon:RegisterDefaultBlock({id='era.hunter.dead-zone',revision=3,families={'era'},class='HUNTER',steps={
 {id='melee',type='branch',conditions={type='BEYOND_MELEE',unit='target'},onTrue={},onFalse={
  BuiltinConditions.spell('raptor-strike',2973,BuiltinConditions.negate({type='SPELL_ACTIVE',spell=2973,ranked=false})),
  BuiltinConditions.spell('mongoose-bite',1495),
  BuiltinConditions.spell('counterattack',19306),
  stop('melee-stop',true),
 }},
}}))
-- Vanilla pull, Auto Shot, Hunter's Mark, moving and the multi-target branch.
assert(addon:RegisterDefaultBlock({id='era.hunter.opening',revision=3,families={'era'},class='HUNTER',steps={
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-mark',1130,unmarked),
  BuiltinConditions.spell('pull-aimed-shot',19434,standing),
  {id='pull-auto-shot',type='spell',action=75,ranked=true,conditions=BuiltinConditions.negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true})},
  stop('pull-stop'),
 }},
 {id='auto-shot',type='spell',action=75,ranked=true,conditions=BuiltinConditions.all(BuiltinConditions.negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true}),standing)},
 BuiltinConditions.spell('mark',1130,BuiltinConditions.all(unmarked,BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite'),BuiltinConditions.classified('rareelite'),
  {type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.5},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=8}))),
 -- Multi-Shot has a hidden cast in vanilla, so on the move only instants.
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  BuiltinConditions.spell('moving-serpent-sting',1978,stingless),
  BuiltinConditions.spell('moving-arcane-shot',3044),
  stop('moving-stop'),
 }},
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('aoe-multi-shot',2643,afterAuto(1)),
  BuiltinConditions.spell('aoe-volley',1510,BuiltinConditions.all(standing,{type='SPELL_COOLDOWN',spell=2643,ranked=false,operator='GREATERTHAN',value=1},
   {type='DISTANCE_COUNT',enemy=true,distance=20,operator='GREATERTHANOREQUALS',value=4})),
 }},
}}))
-- Solo leveling economy: the pet tanks, your own sting, extra shots only on spare mana.
assert(addon:RegisterDefaultBlock({id='era.hunter.solo',revision=2,families={'era'},class='HUNTER',steps={
 BuiltinConditions.spell('concussive-shot',5116,BuiltinConditions.all(BuiltinConditions.negate({type='PET'}),attacked,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=5116,anyrank=true}))),
 BuiltinConditions.spell('serpent-sting',1978,BuiltinConditions.all(stingless,lives)),
 BuiltinConditions.spell('aimed-shot',19434,BuiltinConditions.all(mana('GREATERTHAN',.5),afterAuto(.5))),
 BuiltinConditions.spell('arcane-shot',3044,mana('GREATERTHAN',.5)),
 BuiltinConditions.spell('multi-shot',2643,BuiltinConditions.all(mana('GREATERTHAN',.4),afterAuto(1))),
 stop('wait'),
}}))
-- Vanilla aspect: Hawk in combat (a travel aspect dazes you when struck) or when no aspect is up.
assert(addon:RegisterDefaultBlock({id='era.hunter.hawk',revision=1,families={'era'},class='HUNTER',steps={
 BuiltinConditions.spell('hawk',13165,BuiltinConditions.all(BuiltinConditions.negate(buff(13165)),BuiltinConditions.any(BuiltinConditions.combat(),BuiltinConditions.all(BuiltinConditions.negate(buff(13163)),BuiltinConditions.negate(buff(5118)),BuiltinConditions.negate(buff(13159)),BuiltinConditions.negate(buff(13161)),BuiltinConditions.negate(buff(20043)))))),
}}))
-- Independent reminders every Hunter premade shares: Monkey before Hawk, Trueshot Aura, pet care,
-- Intimidation when solo and attacked, Feign Death on aggro in a group or when low with a pet.
assert(addon:RegisterDefaultBlock({id='era.hunter.upkeep',revision=1,families={'era'},class='HUNTER',steps={
 BuiltinConditions.spell('monkey',13163,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(13165)),BuiltinConditions.negate(buff(13163)),BuiltinConditions.negate(buff(5118)))),
 BuiltinConditions.spell('trueshot-aura',19506,BuiltinConditions.negate(buff(19506))),
 BuiltinConditions.spell('call-pet',883,BuiltinConditions.negate({type='PET'})),
 BuiltinConditions.spell('revive-pet',982,{type='DEAD',unit='pet'}),
 BuiltinConditions.spell('mend-pet',136,BuiltinConditions.all({type='PET'},{type='HEALTHPCT',unit='pet',operator='LESSTHAN',value=.5},BuiltinConditions.negate({type='BUFF',unit='pet',spell=136,anyrank=true}))),
 BuiltinConditions.spell('intimidation',19577,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),attacked)),
 BuiltinConditions.spell('feign-death',5384,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.all({type='GROUP'},{type='THREAT',unit='target',threat=3}),
  BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.35},{type='PET'})))),
}}))
-- Season of Discovery: the same reminders, but with the Lone Wolf rune (415370, passive: more damage
-- without a pet) engraved, never call or revive a pet.
assert(addon:RegisterDefaultBlock({id='sod.hunter.upkeep',revision=1,families={'era'},class='HUNTER',steps={
 BuiltinConditions.spell('monkey',13163,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(13165)),BuiltinConditions.negate(buff(13163)),BuiltinConditions.negate(buff(5118)))),
 BuiltinConditions.spell('trueshot-aura',19506,BuiltinConditions.negate(buff(19506))),
 BuiltinConditions.spell('call-pet',883,BuiltinConditions.all(BuiltinConditions.negate({type='PET'}),BuiltinConditions.negate(loneWolf))),
 BuiltinConditions.spell('revive-pet',982,BuiltinConditions.all({type='DEAD',unit='pet'},BuiltinConditions.negate(loneWolf))),
 BuiltinConditions.spell('mend-pet',136,BuiltinConditions.all({type='PET'},{type='HEALTHPCT',unit='pet',operator='LESSTHAN',value=.5},BuiltinConditions.negate({type='BUFF',unit='pet',spell=136,anyrank=true}))),
 BuiltinConditions.spell('intimidation',19577,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='GROUP'}),attacked)),
 BuiltinConditions.spell('feign-death',5384,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.all({type='GROUP'},{type='THREAT',unit='target',threat=3}),
  BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.35},{type='PET'})))),
}}))
-- Major cooldowns only where they pay: elites, bosses, dungeons, raids, or a target that lives 20 s.
local worth=BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite'),BuiltinConditions.classified('rareelite'),instance('party'),instance('raid'),
 {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=20}))
assert(addon:RegisterDefaultBlock({id='era.hunter.cooldowns',revision=1,families={'era'},class='HUNTER',steps={
 BuiltinConditions.spell('rapid-fire',3045,BuiltinConditions.all(worth,BuiltinConditions.negate(buff(3045)))),
 BuiltinConditions.spell('bestial-wrath',19574,BuiltinConditions.all(worth,{type='PET'})),
 BuiltinConditions.spell('berserking',20554,BuiltinConditions.all(worth,buff(3045))),
 BuiltinConditions.spell('blood-fury',20572,BuiltinConditions.all(worth,buff(3045))),
}}))
