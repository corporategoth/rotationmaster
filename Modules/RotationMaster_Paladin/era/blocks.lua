-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Classic Era and Season of Discovery Paladin blocks (Built In composition; authoring-time only).
-- Consumers: rm.era.paladin.* (era.paladin.*) and rm.sod.paladin.* (era.paladin.* and sod.paladin.*).
-- A content change needs a revision bump, every consumer's `blocks` pin and revision bumped,
-- and ledger rows in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function own(id)return{type='BUFF',unit='player',spell=id,anyrank=true,ownbuff=true}end
local function health(v)return{type='HEALTHPCT',unit='player',operator='LESSTHAN',value=v}end
local function hurt(v)return{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=v}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function list(ids,make)local out={};for i,id in ipairs(ids)do out[i]=make(id)end;return{type='OR',value=out}end
local forbearance={type='DEBUFF',unit='player',spell=25771}
local undead=BuiltinConditions.any({type='CREATURE',unit='target',value='UNDEAD'},{type='CREATURE',unit='target',value='DEMON'})
-- Any aura you chose (Devotion, Retribution, Concentration, Sanctity, resistances). Auras are stances,
-- read by spell (any rank), never by stance-bar index, which moves as auras are learned.
local function noAura()return BuiltinConditions.negate(list({465,7294,19746,20218,19876,19888,19891},function(id)return{type='FORM',form=id}end))end
-- Any blessing from anyone: normal and Greater Might, Wisdom, Kings, Salvation, Sanctuary, Light.
local function noBlessing()return BuiltinConditions.negate(list({19740,19742,20217,1038,20911,19977,25782,25894,25898,25895,25899,25890},
 function(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end))end
-- Any seal of yours: Righteousness (both rank-1 IDs), Command, the Crusader, Wisdom, Light, Justice, Martyrdom.
local function sealed()return list({20154,21084,20375,21082,20166,20165,20164,407798},own)end
local function paladin(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'era'},class='PALADIN',steps=steps}))end
paladin('era.paladin.boundaries',{
 {id='casting',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})},
},2)
-- Melee premades: a cast or channel, or no attackable target, ends advice (one Stop).
paladin('era.paladin.melee-opening',{
 {id='casting',type='stop',suppress_attack=true,conditions=BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))},
},3)
-- Solo safety (Icy Veins Hardcore overview): bubble below 20% health unless Forbearance
-- blocks it, Divine Protection before Divine Shield is learned, Lay on Hands below 10%.
paladin('era.paladin.safety',{
 BuiltinConditions.spell('divine-shield',642,BuiltinConditions.all(BuiltinConditions.combat(),health(0.2),BuiltinConditions.negate(forbearance))),
 BuiltinConditions.spell('divine-protection',498,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(642)),BuiltinConditions.combat(),health(0.2),BuiltinConditions.negate(forbearance))),
 BuiltinConditions.spell('lay-on-hands',633,BuiltinConditions.all(BuiltinConditions.combat(),health(0.1))),
})
-- Vanilla Retribution upkeep (Icy Veins, Warcraft Tavern): Sanctity, else Retribution, else
-- Devotion Aura; Wisdom solo, Might in a group; heal between fights.
paladin('era.paladin.ret-upkeep',{
 BuiltinConditions.spell('sanctity-aura',20218,noAura()),
 BuiltinConditions.spell('retribution-aura',7294,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(20218)),noAura())),
 BuiltinConditions.spell('devotion-aura',465,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(20218)),BuiltinConditions.negate(BuiltinConditions.known(7294)),noAura())),
 BuiltinConditions.spell('blessing-of-wisdom',19742,BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),noBlessing())),
 BuiltinConditions.spell('blessing-of-might',19740,BuiltinConditions.all(BuiltinConditions.any({type='GROUP'},BuiltinConditions.negate(BuiltinConditions.known(19742))),noBlessing())),
 BuiltinConditions.spell('flash-of-light',19750,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),health(0.6))),
 BuiltinConditions.spell('holy-light',635,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(19750)),BuiltinConditions.negate(BuiltinConditions.combat()),health(0.6))),
},2)
-- Vanilla re-seal: Command with a slow weapon (3.5 s or more), else Righteousness.
paladin('era.paladin.seal',{
 {id='seal',type='branch',conditions=sealed(),onTrue={},onFalse={
  BuiltinConditions.spell('seal-command',20375,{type='SWING_TIME',offhand=false,operator='GREATERTHANOREQUALS',value=3.5}),
  BuiltinConditions.spell('seal-righteousness',20154),
 }},
},2)
-- Judgement of the Crusader once per long fight (Icy Veins, Wowhead): judge an active Seal of the
-- Crusader; put it up only when nobody's judgement is on the target, outside raids, on an elite or
-- a target that will live 30 s, and Judgement is ready.
paladin('era.paladin.crusader-opener',{
 BuiltinConditions.spell('crusader-judgement',20271,own(21082)),
 BuiltinConditions.spell('crusader-seal',21082,BuiltinConditions.all(BuiltinConditions.negate({type='DEBUFF',unit='target',spell=21183,anyrank=true}),BuiltinConditions.negate({type='GROUP',raid=true}),{type='SPELL_AVAIL',spell=20271},
  BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},{type='CLASSIFICATION',unit='target',value='worldboss'},
   {type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=30}))),
})
-- Undead and Demons (every source): Exorcism, Holy Wrath on two or more close enemies.
paladin('era.paladin.undead',{
 {id='undead',type='branch',conditions=undead,onFalse={},onTrue={
  BuiltinConditions.spell('exorcism',879),
  BuiltinConditions.spell('holy-wrath',2812,{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2}),
 }},
})
-- Vanilla tank upkeep (Wowhead's Askalon, Icy Veins): Righteous Fury, Devotion unless you chose
-- another aura, Sanctuary, else Kings, else Might; Lay on Hands as the last resort.
paladin('era.paladin.tank-upkeep',{
 BuiltinConditions.spell('righteous-fury',25780,BuiltinConditions.negate(own(25780))),
 BuiltinConditions.spell('devotion-aura',465,noAura()),
 BuiltinConditions.spell('blessing-of-sanctuary',20911,noBlessing()),
 BuiltinConditions.spell('blessing-of-kings',20217,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(20911)),noBlessing())),
 BuiltinConditions.spell('blessing-of-might',19740,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(20911)),BuiltinConditions.negate(BuiltinConditions.known(20217)),noBlessing())),
 BuiltinConditions.spell('lay-on-hands',633,BuiltinConditions.all(BuiltinConditions.combat(),health(0.1))),
},2)
-- Vanilla healer upkeep (Icy Veins, Wowhead): Concentration, else Devotion Aura; Wisdom; Divine
-- Favor and Lay on Hands for a friendly target that is very low.
paladin('era.paladin.holy-upkeep',{
 BuiltinConditions.spell('concentration-aura',19746,noAura()),
 BuiltinConditions.spell('devotion-aura',465,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(19746)),noAura())),
 BuiltinConditions.spell('blessing-of-wisdom',19742,noBlessing()),
 BuiltinConditions.spell('divine-favor',20216,BuiltinConditions.all(BuiltinConditions.combat(),{type='FRIENDLY',unit='target'},hurt(0.4))),
 BuiltinConditions.spell('lay-on-hands',633,BuiltinConditions.all(BuiltinConditions.combat(),{type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'}),hurt(0.15))),
},2)
-- Cleanse (Purify before 42) on a friendly target with something you can remove.
paladin('era.paladin.cleanse',{
 BuiltinConditions.spell('cleanse',4987,BuiltinConditions.any({type='DISPELLABLE',unit='target',debufftype='Magic'},{type='DISPELLABLE',unit='target',debufftype='Poison'},{type='DISPELLABLE',unit='target',debufftype='Disease'})),
 BuiltinConditions.spell('purify',1152,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(4987)),BuiltinConditions.any({type='DISPELLABLE',unit='target',debufftype='Poison'},{type='DISPELLABLE',unit='target',debufftype='Disease'}))),
})
-- Season of Discovery Retribution upkeep (Wowhead Phase 8, Icy Veins): Sanctity, Wisdom solo or
-- Might in a group, Avenging Wrath on a target that lives (at three Holy Power when the set gives
-- them), Aura Mastery with it, a heal between fights.
paladin('sod.paladin.ret-upkeep',{
 BuiltinConditions.spell('sanctity-aura',20218,noAura()),
 BuiltinConditions.spell('retribution-aura',7294,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(20218)),noAura())),
 BuiltinConditions.spell('devotion-aura',465,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(20218)),BuiltinConditions.negate(BuiltinConditions.known(7294)),noAura())),
 BuiltinConditions.spell('blessing-of-wisdom',19742,BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),noBlessing())),
 BuiltinConditions.spell('blessing-of-might',19740,BuiltinConditions.all(BuiltinConditions.any({type='GROUP'},BuiltinConditions.negate(BuiltinConditions.known(19742))),noBlessing())),
 BuiltinConditions.spell('avenging-wrath',407788,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(forbearance),
  BuiltinConditions.any(BuiltinConditions.negate({type='BUFF',unit='player',spell=1226461}),{type='BUFF_STACKS',unit='player',spell=1226461,operator='GREATERTHANOREQUALS',value=3}),
  BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20}))),
 BuiltinConditions.spell('aura-mastery',407624,BuiltinConditions.all(BuiltinConditions.combat(),own(407788))),
 BuiltinConditions.spell('flash-of-light',19750,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),health(0.6))),
 BuiltinConditions.spell('holy-light',635,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(19750)),BuiltinConditions.negate(BuiltinConditions.combat()),health(0.6))),
},2)
-- Season of Discovery re-seal: Martyrdom (baseline from level 1), else Righteousness.
paladin('sod.paladin.seal',{
 {id='seal',type='branch',conditions=sealed(),onTrue={},onFalse={
  BuiltinConditions.spell('seal-martyrdom',407798),
  BuiltinConditions.spell('seal-righteousness',20154),
 }},
},2)
-- Season of Discovery tank upkeep (Wowhead Phase 8, simulator, Icy Veins): Righteous Fury, Holy
-- Shield before a pull, Devotion, Sanctuary or Kings, Avenging Wrath in combat, Divine Protection
-- (Malleable Protection) below 40%, Lay on Hands below 10%, Hand of Reckoning in a group when your
-- target is not attacking you.
paladin('sod.paladin.tank-upkeep',{
 BuiltinConditions.spell('righteous-fury',407627,BuiltinConditions.negate(BuiltinConditions.any(own(407627),own(25780)))),
 BuiltinConditions.spell('holy-shield',20925,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(own(20925)))),
 BuiltinConditions.spell('devotion-aura',465,noAura()),
 BuiltinConditions.spell('blessing-of-sanctuary',20911,noBlessing()),
 BuiltinConditions.spell('blessing-of-kings',20217,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(20911)),noBlessing())),
 BuiltinConditions.spell('blessing-of-might',19740,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(20911)),BuiltinConditions.negate(BuiltinConditions.known(20217)),noBlessing())),
 BuiltinConditions.spell('avenging-wrath',407788,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(forbearance))),
 BuiltinConditions.spell('divine-protection',458371,BuiltinConditions.all(BuiltinConditions.combat(),health(0.4),BuiltinConditions.negate(forbearance))),
 BuiltinConditions.spell('lay-on-hands',633,BuiltinConditions.all(BuiltinConditions.combat(),health(0.1))),
 BuiltinConditions.spell('hand-of-reckoning',407631,BuiltinConditions.all(BuiltinConditions.combat(),{type='GROUP'},{type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='THREAT',unit='target',threat=3}))),
},2)
-- Season of Discovery healer upkeep (Icy Veins, Wowhead, Warcraft Tavern Phase 4): Concentration or
-- Devotion, Wisdom, your Beacon of Light and Sacred Shield on the friendly target that lacks them,
-- Divine Favor and Lay on Hands for a target that is very low.
local friend=BuiltinConditions.all({type='FRIENDLY',unit='target'},BuiltinConditions.negate({type='DEAD',unit='target'}))
paladin('sod.paladin.holy-upkeep',{
 BuiltinConditions.spell('concentration-aura',19746,noAura()),
 BuiltinConditions.spell('devotion-aura',465,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(19746)),noAura())),
 BuiltinConditions.spell('blessing-of-wisdom',19742,noBlessing()),
 BuiltinConditions.spell('beacon-of-light',407613,BuiltinConditions.all(friend,BuiltinConditions.negate({type='BUFF',unit='target',spell=407613,ownbuff=true}))),
 BuiltinConditions.spell('sacred-shield',412019,BuiltinConditions.all(friend,BuiltinConditions.negate({type='BUFF',unit='target',spell=412019,ownbuff=true}))),
 BuiltinConditions.spell('divine-favor',20216,BuiltinConditions.all(BuiltinConditions.combat(),friend,hurt(0.4))),
 BuiltinConditions.spell('lay-on-hands',633,BuiltinConditions.all(BuiltinConditions.combat(),friend,hurt(0.15))),
},2)
-- A healer with an enemy in melee range: a seal for Sheath of Light and mana, then nothing.
paladin('sod.paladin.holy-hostile',{
 {id='hostile',type='branch',conditions=BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.negate({type='BEYOND_MELEE',unit='target'})),onFalse={},onTrue={
  {id='seal',type='branch',conditions=sealed(),onTrue={},onFalse={BuiltinConditions.spell('seal-martyrdom',407798),BuiltinConditions.spell('seal-wisdom',20166)}},
 }},
 {id='hostile-stop',type='stop',conditions={type='ATTACKABLE',unit='target'}},
 {id='idle-stop',type='stop',suppress_attack=true,conditions={}},
},3)
