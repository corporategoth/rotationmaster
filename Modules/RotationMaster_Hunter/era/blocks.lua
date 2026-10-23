-- Shared Classic Era Hunter blocks (Built In composition; authoring-time only).
-- Consumers: rm.era.hunter.ranged, rm.era.hunter.ranged.icyveins, rm.era.hunter.ranged.wowsims,
-- rm.sod.hunter.ranged and rm.sod.hunter.melee (which use sod.hunter.upkeep). A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research era/hunter.md.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function mana(op,n)return{type='MANAPCT',unit='player',operator=op,value=n}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function instance(kind)return{type='INSTANCE',value=kind}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,attack)return{id=id,type='none',suppress_attack=not attack,conditions={}}end
local function afterAuto(window)return{type='SPELL_HISTORY_TIME',spell=75,ranked=true,operator='LESSTHANOREQUALS',value=window}end
local standing=negate({type='MOVING'})
local unmarked=negate({type='DEBUFF',unit='target',spell=1130,anyrank=true})
local stingless=all(negate({type='DEBUFF',unit='target',spell=1978,anyrank=true,owndebuff=true}),
 negate({type='DEBUFF',unit='target',spell=3043,anyrank=true,owndebuff=true}),negate({type='DEBUFF',unit='target',spell=3034,anyrank=true,owndebuff=true}))
local lives=any({type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.3},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=8})
local attacked={type='ISSAME',unit='targettarget',otherunit='player'}
local loneWolf={type='RUNE_ENGRAVED',spell=415370}
-- Casts and channels (Aimed Shot, Steady Shot, Volley, Mend Pet) and a missing target end advice.
assert(addon:RegisterDefaultBlock({id='era.hunter.boundaries',revision=1,families={'era'},class='HUNTER',steps={
 {id='manual',type='none',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
 {id='no-target',type='none',suppress_attack=true,conditions=negate({type='ATTACKABLE',unit='target'})},
}}))
-- Vanilla dead zone: inside melee range only the melee buttons work.
assert(addon:RegisterDefaultBlock({id='era.hunter.dead-zone',revision=2,families={'era'},class='HUNTER',steps={
 {id='melee',type='branch',conditions={type='BEYOND_MELEE',unit='target'},onTrue={},onFalse={
  spell('raptor-strike',2973,negate({type='SPELL_ACTIVE',spell=2973,ranked=false})),
  spell('mongoose-bite',1495),
  spell('counterattack',19306),
  stop('melee-stop',true),
 }},
}}))
-- Vanilla pull, Auto Shot, Hunter's Mark, moving and the multi-target branch.
assert(addon:RegisterDefaultBlock({id='era.hunter.opening',revision=2,families={'era'},class='HUNTER',steps={
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('pull-mark',1130,unmarked),
  spell('pull-aimed-shot',19434,standing),
  {id='pull-auto-shot',type='spell',action=75,ranked=true,conditions=negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true})},
  stop('pull-stop'),
 }},
 {id='auto-shot',type='spell',action=75,ranked=true,conditions=all(negate({type='SPELL_AUTOREPEAT',spell=75,ranked=true}),standing)},
 spell('mark',1130,all(unmarked,any(classified('worldboss'),classified('elite'),classified('rareelite'),
  {type='HEALTHPCT',unit='target',operator='GREATERTHAN',value=.5},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=8}))),
 -- Multi-Shot has a hidden cast in vanilla, so on the move only instants.
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('moving-serpent-sting',1978,stingless),
  spell('moving-arcane-shot',3044),
  stop('moving-stop'),
 }},
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('aoe-multi-shot',2643,afterAuto(1)),
  spell('aoe-volley',1510,all(standing,{type='SPELL_COOLDOWN',spell=2643,ranked=false,operator='GREATERTHAN',value=1},
   {type='DISTANCE_COUNT',enemy=true,distance=20,operator='GREATERTHANOREQUALS',value=4})),
 }},
}}))
-- Solo leveling economy: the pet tanks, your own sting, extra shots only on spare mana.
assert(addon:RegisterDefaultBlock({id='era.hunter.solo',revision=1,families={'era'},class='HUNTER',steps={
 spell('concussive-shot',5116,all(negate({type='PET'}),attacked,negate({type='DEBUFF',unit='target',spell=5116,anyrank=true}))),
 spell('serpent-sting',1978,all(stingless,lives)),
 spell('aimed-shot',19434,all(mana('GREATERTHAN',.5),afterAuto(.5))),
 spell('arcane-shot',3044,mana('GREATERTHAN',.5)),
 spell('multi-shot',2643,all(mana('GREATERTHAN',.4),afterAuto(1))),
 stop('wait'),
}}))
-- Vanilla aspect: Hawk in combat (a travel aspect dazes you when struck) or when no aspect is up.
assert(addon:RegisterDefaultBlock({id='era.hunter.hawk',revision=1,families={'era'},class='HUNTER',steps={
 spell('hawk',13165,all(negate(buff(13165)),any(combat(),all(negate(buff(13163)),negate(buff(5118)),negate(buff(13159)),negate(buff(13161)),negate(buff(20043)))))),
}}))
-- Independent reminders every Hunter premade shares: Monkey before Hawk, Trueshot Aura, pet care,
-- Intimidation when solo and attacked, Feign Death on aggro in a group or when low with a pet.
assert(addon:RegisterDefaultBlock({id='era.hunter.upkeep',revision=1,families={'era'},class='HUNTER',steps={
 spell('monkey',13163,all(negate(known(13165)),negate(buff(13163)),negate(buff(5118)))),
 spell('trueshot-aura',19506,negate(buff(19506))),
 spell('call-pet',883,negate({type='PET'})),
 spell('revive-pet',982,{type='DEAD',unit='pet'}),
 spell('mend-pet',136,all({type='PET'},{type='HEALTHPCT',unit='pet',operator='LESSTHAN',value=.5},negate({type='BUFF',unit='pet',spell=136,anyrank=true}))),
 spell('intimidation',19577,all(combat(),negate({type='GROUP'}),attacked)),
 spell('feign-death',5384,all(combat(),any(all({type='GROUP'},{type='THREAT',unit='target',threat=3}),
  all(negate({type='GROUP'}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.35},{type='PET'})))),
}}))
-- Season of Discovery: the same reminders, but with the Lone Wolf rune (415370, passive: more damage
-- without a pet) engraved, never call or revive a pet.
assert(addon:RegisterDefaultBlock({id='sod.hunter.upkeep',revision=1,families={'era'},class='HUNTER',steps={
 spell('monkey',13163,all(negate(known(13165)),negate(buff(13163)),negate(buff(5118)))),
 spell('trueshot-aura',19506,negate(buff(19506))),
 spell('call-pet',883,all(negate({type='PET'}),negate(loneWolf))),
 spell('revive-pet',982,all({type='DEAD',unit='pet'},negate(loneWolf))),
 spell('mend-pet',136,all({type='PET'},{type='HEALTHPCT',unit='pet',operator='LESSTHAN',value=.5},negate({type='BUFF',unit='pet',spell=136,anyrank=true}))),
 spell('intimidation',19577,all(combat(),negate({type='GROUP'}),attacked)),
 spell('feign-death',5384,all(combat(),any(all({type='GROUP'},{type='THREAT',unit='target',threat=3}),
  all(negate({type='GROUP'}),{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=.35},{type='PET'})))),
}}))
-- Major cooldowns only where they pay: elites, bosses, dungeons, raids, or a target that lives 20 s.
local worth=all(combat(),any(classified('worldboss'),classified('elite'),classified('rareelite'),instance('party'),instance('raid'),
 {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=20}))
assert(addon:RegisterDefaultBlock({id='era.hunter.cooldowns',revision=1,families={'era'},class='HUNTER',steps={
 spell('rapid-fire',3045,all(worth,negate(buff(3045)))),
 spell('bestial-wrath',19574,all(worth,{type='PET'})),
 spell('berserking',20554,all(worth,buff(3045))),
 spell('blood-fury',20572,all(worth,buff(3045))),
}}))
