-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Classic Era and Season of Discovery Paladin blocks (Built In composition; authoring-time only).
-- Consumers: rm.era.paladin.* (era.paladin.*) and rm.sod.paladin.* (era.paladin.* and sod.paladin.*).
-- A content change needs a revision bump, every consumer's `blocks` pin and revision bumped,
-- and ledger rows in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function health(v)return{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=v}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function list(ids,make)local out={};for i,id in ipairs(ids)do out[i]=make(id)end;return{type='OR',value=out}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or{}}end
local forbearance={type='DEBUFF',unit='player',spell=25771}
local undead=any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})
-- Any aura you chose (Devotion, Retribution, Concentration, Sanctity, resistances). Auras are stances,
-- read by spell (any rank), never by stance-bar index, which moves as auras are learned.
local function noAura()return negate(list({465,7294,19746,20218,19876,19888,19891},function(id)return{type='FORM',form=id}end))end
-- Any blessing from anyone: normal and Greater Might, Wisdom, Kings, Salvation, Sanctuary, Light.
local function noBlessing()return negate(list({19740,19742,20217,1038,20911,19977,25782,25894,25898,25895,25899,25890},
 function(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end))end
-- Any seal of yours: Righteousness (both rank-1 IDs), Command, the Crusader, Wisdom, Light, Justice, Martyrdom.
local function sealed()return list({20154,21084,20375,21082,20166,20165,20164,407798},own)end
local function paladin(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'era'},class='PALADIN',steps=steps}))end
paladin('era.paladin.boundaries',{
 {id='casting',type='stop',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
},2)
-- Melee premades: a cast or channel, or no attackable target, ends advice (one Stop).
paladin('era.paladin.melee-opening',{
 {id='casting',type='stop',suppress_attack=true,conditions=any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},negate({type='ATTACKABLE',unit='target'}))},
},3)
-- Solo safety (Icy Veins Hardcore overview): bubble below 20% health unless Forbearance
-- blocks it, Divine Protection before Divine Shield is learned, Lay on Hands below 10%.
paladin('era.paladin.safety',{
 spell('divine-shield',642,all(combat(),health(0.2),negate(forbearance))),
 spell('divine-protection',498,all(negate(known(642)),combat(),health(0.2),negate(forbearance))),
 spell('lay-on-hands',633,all(combat(),health(0.1))),
})
-- Vanilla Retribution upkeep (Icy Veins, Warcraft Tavern): Sanctity, else Retribution, else
-- Devotion Aura; Wisdom solo, Might in a group; heal between fights.
paladin('era.paladin.ret-upkeep',{
 spell('sanctity-aura',20218,noAura()),
 spell('retribution-aura',7294,all(negate(known(20218)),noAura())),
 spell('devotion-aura',465,all(negate(known(20218)),negate(known(7294)),noAura())),
 spell('blessing-of-wisdom',19742,all(negate({type='GROUP'}),noBlessing())),
 spell('blessing-of-might',19740,all(any({type='GROUP'},negate(known(19742))),noBlessing())),
 spell('flash-of-light',19750,all(negate(combat()),health(0.6))),
 spell('holy-light',635,all(negate(known(19750)),negate(combat()),health(0.6))),
},2)
-- Vanilla re-seal: Command with a slow weapon (3.5 s or more), else Righteousness.
paladin('era.paladin.seal',{
 {id='seal',type='branch',conditions=sealed(),onTrue={},onFalse={
  spell('seal-command',20375,{type='SWING_TIME',offhand=false,operator='GREATERTHANOREQUALS',value=3.5}),
  spell('seal-righteousness',20154),
 }},
},2)
-- Judgement of the Crusader once per long fight (Icy Veins, Wowhead): judge an active Seal of the
-- Crusader; put it up only when nobody's judgement is on the target, outside raids, on an elite or
-- a target that will live 30 s, and Judgement is ready.
paladin('era.paladin.crusader-opener',{
 spell('crusader-judgement',20271,own(21082)),
 spell('crusader-seal',21082,all(negate({type='DEBUFF',unit='target',spell=21183,anyrank=true}),negate({type='GROUP',raid=true}),{type='SPELL_AVAIL',spell=20271},
  any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'},
   {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=30}))),
})
-- Undead and Demons (every source): Exorcism, Holy Wrath on two or more close enemies.
paladin('era.paladin.undead',{
 {id='undead',type='branch',conditions=undead,onFalse={},onTrue={
  spell('exorcism',879),
  spell('holy-wrath',2812,{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2}),
 }},
})
-- Vanilla tank upkeep (Wowhead's Askalon, Icy Veins): Righteous Fury, Devotion unless you chose
-- another aura, Sanctuary, else Kings, else Might; Lay on Hands as the last resort.
paladin('era.paladin.tank-upkeep',{
 spell('righteous-fury',25780,negate(own(25780))),
 spell('devotion-aura',465,noAura()),
 spell('blessing-of-sanctuary',20911,noBlessing()),
 spell('blessing-of-kings',20217,all(negate(known(20911)),noBlessing())),
 spell('blessing-of-might',19740,all(negate(known(20911)),negate(known(20217)),noBlessing())),
 spell('lay-on-hands',633,all(combat(),health(0.1))),
},2)
-- Vanilla healer upkeep (Icy Veins, Wowhead): Concentration, else Devotion Aura; Wisdom; Divine
-- Favor and Lay on Hands for a friendly target that is very low.
paladin('era.paladin.holy-upkeep',{
 spell('concentration-aura',19746,noAura()),
 spell('devotion-aura',465,all(negate(known(19746)),noAura())),
 spell('blessing-of-wisdom',19742,noBlessing()),
 spell('divine-favor',20216,all(combat(),{type='FRIENDLY',unit='target'},hurt(0.4))),
 spell('lay-on-hands',633,all(combat(),{type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'}),hurt(0.15))),
},2)
-- Cleanse (Purify before 42) on a friendly target with something you can remove.
paladin('era.paladin.cleanse',{
 spell('cleanse',4987,any({type='DISPELLABLE',unit='target',debufftype='Magic'},{type='DISPELLABLE',unit='target',debufftype='Poison'},{type='DISPELLABLE',unit='target',debufftype='Disease'})),
 spell('purify',1152,all(negate(known(4987)),any({type='DISPELLABLE',unit='target',debufftype='Poison'},{type='DISPELLABLE',unit='target',debufftype='Disease'}))),
})
-- Season of Discovery Retribution upkeep (Wowhead Phase 8, Icy Veins): Sanctity, Wisdom solo or
-- Might in a group, Avenging Wrath on a target that lives (at three Holy Power when the set gives
-- them), Aura Mastery with it, a heal between fights.
paladin('sod.paladin.ret-upkeep',{
 spell('sanctity-aura',20218,noAura()),
 spell('retribution-aura',7294,all(negate(known(20218)),noAura())),
 spell('devotion-aura',465,all(negate(known(20218)),negate(known(7294)),noAura())),
 spell('blessing-of-wisdom',19742,all(negate({type='GROUP'}),noBlessing())),
 spell('blessing-of-might',19740,all(any({type='GROUP'},negate(known(19742))),noBlessing())),
 spell('avenging-wrath',407788,all(combat(),negate(forbearance),
  any(negate({type='BUFF',unit='player',spell=1226461}),{type='BUFF_STACKS',unit='player',spell=1226461,operator='GREATERTHANOREQUALS',value=3}),
  any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20}))),
 spell('aura-mastery',407624,all(combat(),own(407788))),
 spell('flash-of-light',19750,all(negate(combat()),health(0.6))),
 spell('holy-light',635,all(negate(known(19750)),negate(combat()),health(0.6))),
},2)
-- Season of Discovery re-seal: Martyrdom (baseline from level 1), else Righteousness.
paladin('sod.paladin.seal',{
 {id='seal',type='branch',conditions=sealed(),onTrue={},onFalse={
  spell('seal-martyrdom',407798),
  spell('seal-righteousness',20154),
 }},
},2)
-- Season of Discovery tank upkeep (Wowhead Phase 8, simulator, Icy Veins): Righteous Fury, Holy
-- Shield before a pull, Devotion, Sanctuary or Kings, Avenging Wrath in combat, Divine Protection
-- (Malleable Protection) below 40%, Lay on Hands below 10%, Hand of Reckoning in a group when your
-- target is not attacking you.
paladin('sod.paladin.tank-upkeep',{
 spell('righteous-fury',407627,negate(any(own(407627),own(25780)))),
 spell('holy-shield',20925,all(negate(combat()),negate(own(20925)))),
 spell('devotion-aura',465,noAura()),
 spell('blessing-of-sanctuary',20911,noBlessing()),
 spell('blessing-of-kings',20217,all(negate(known(20911)),noBlessing())),
 spell('blessing-of-might',19740,all(negate(known(20911)),negate(known(20217)),noBlessing())),
 spell('avenging-wrath',407788,all(combat(),negate(forbearance))),
 spell('divine-protection',458371,all(combat(),health(0.4),negate(forbearance))),
 spell('lay-on-hands',633,all(combat(),health(0.1))),
 spell('hand-of-reckoning',407631,all(combat(),{type='GROUP'},{type='ATTACKABLE',unit='target'},negate({type='THREAT',unit='target',threat=3}))),
},2)
-- Season of Discovery healer upkeep (Icy Veins, Wowhead, Warcraft Tavern Phase 4): Concentration or
-- Devotion, Wisdom, your Beacon of Light and Sacred Shield on the friendly target that lacks them,
-- Divine Favor and Lay on Hands for a target that is very low.
local friend=all({type='FRIENDLY',unit='target'},negate({type='DEAD',unit='target'}))
paladin('sod.paladin.holy-upkeep',{
 spell('concentration-aura',19746,noAura()),
 spell('devotion-aura',465,all(negate(known(19746)),noAura())),
 spell('blessing-of-wisdom',19742,noBlessing()),
 spell('beacon-of-light',407613,all(friend,negate({type='BUFF',unit='target',spell=407613,ownbuff=true}))),
 spell('sacred-shield',412019,all(friend,negate({type='BUFF',unit='target',spell=412019,ownbuff=true}))),
 spell('divine-favor',20216,all(combat(),friend,hurt(0.4))),
 spell('lay-on-hands',633,all(combat(),friend,hurt(0.15))),
},2)
-- A healer with an enemy in melee range: a seal for Sheath of Light and mana, then nothing.
paladin('sod.paladin.holy-hostile',{
 {id='hostile',type='branch',conditions=all({type='ATTACKABLE',unit='target'},negate({type='BEYOND_MELEE',unit='target'})),onFalse={},onTrue={
  {id='seal',type='branch',conditions=sealed(),onTrue={},onFalse={spell('seal-martyrdom',407798),spell('seal-wisdom',20166)}},
 }},
 {id='hostile-stop',type='stop',conditions={type='ATTACKABLE',unit='target'}},
 {id='idle-stop',type='stop',suppress_attack=true,conditions={}},
},3)
