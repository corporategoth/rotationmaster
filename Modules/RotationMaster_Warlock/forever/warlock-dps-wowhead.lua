-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Warlock, Wowhead's level-30 guides (player-chosen variant, all three trees).
-- Same switch as the recommended Warlock premade, lowest Warlock priority, off by default.
-- Differs from the
-- default: Affliction and Demonology are drain-tanks (Corruption and Agony, no Immolate, then
-- Drain Life for the rest of the fight with the Succubus; health and mana are secret on Forever,
-- so Life Tap is the player's call;
-- Demonology keeps Demonic Brand up and Agonies only big targets); Destruction puts Agony,
-- Corruption and Immolate on every mob, Conflagrates just before Immolate runs out, keeps
-- Shadowburn for the killing blow and wands when solo with the Voidwalker. Amplify Curse on
-- every cooldown, Curse of the Elements and Bane of Doom only on elites and bosses. Wowhead's
-- guides stop at level 30, so later steps follow the same shape. No pack (AoE) section: the
-- source has none. Shared parts: Defaults/blocks/forever-warlock.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
local function sacrificed()return any(buff(18789),buff(18790),buff(18791),buff(18792))end
local function pact()return all(known(19028),{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=40})end
local function summon()return all(negate({type='PET'}),any(negate(combat()),buff(18708)),any(negate(sacrificed()),pact()))end
local function bane()return all(negate(own(980)),negate(own(603)),negate(any(own(1324473),own(1225228))))end
local destruction=known(1293817)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warlock.dps.wowhead',revision=6,
 blocks={['forever.warlock.boundaries']=3,['forever.warlock.upkeep']=2,['forever.warlock.procs']=1,
  ['forever.warlock.moving']=3,['forever.warlock.wand']=2},
 nameKey="All trees (Wowhead)",descriptionKey="Wowhead's level-30 Warlock: Affliction and Demonology drain-tank with the Succubus (Corruption and Agony, no Immolate, then Drain Life for the rest of the fight; health and mana are hidden on Forever, so Life Tap is your call), Demonology keeps Demonic Brand up and Agonies only big targets, Destruction puts Agony, Corruption and Immolate on every mob, Conflagrates just before Immolate ends, saves Shadowburn for the killing blow and wands with the Voidwalker. Amplify Curse on every cooldown; Curse of the Elements and Bane of Doom only on elites and bosses; no pack section. Wowhead's guides stop at level 30. An alternative to the recommended Warlock DPS premade, off by default: enable it and disable that one, or raise its priority.",
 applicability={families={'forever'},actionContext='player',class='WARLOCK'},
 tags={'dps','ranged','caster','leveling','wowhead'},
 sources={{url='https://www.wowhead.com/forever/guide/classes/warlock/affliction/level-30-dps-overview',title='Wowhead: Forever level 30 Affliction Warlock',reviewedAt='2026-10-23',revision='2026-10-09'},
 {url='https://www.wowhead.com/forever/guide/classes/warlock/demonology/level-30-dps-overview',title='Wowhead: Forever level 30 Demonology Warlock',reviewedAt='2026-10-23',revision='2026-10-09'},
 {url='https://www.wowhead.com/forever/guide/classes/warlock/destruction/level-30-dps-overview',title='Wowhead: Forever level 30 Destruction Warlock',reviewedAt='2026-10-23',revision='2026-10-09'}},
 body={priority=5,disabled=true,
 cooldowns={block('forever.warlock.upkeep','warlock-wh-'),
  spell('warlock-wh-summon-destro-voidwalker',697,all(destruction,summon())),
  spell('warlock-wh-summon-succubus',712,all(negate(destruction),summon())),
  spell('warlock-wh-summon-voidwalker',697,all(negate(destruction),negate(known(712)),summon())),
  spell('warlock-wh-summon-imp',688,all(negate(known(712)),negate(known(697)),summon())),
  spell('warlock-wh-amplify-curse',18288,combat())},
 rotation={
 block('forever.warlock.boundaries','warlock-wh-'),
 {id='warlock-wh-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('warlock-wh-pull-corruption',172,negate(own(172))),
  spell('warlock-wh-pull-agony',980,all(bane(),any(negate(known(18708)),big()))),
  spell('warlock-wh-pull-immolate',348,all(destruction,negate(own(348)))),
  {id='warlock-wh-pull-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 block('forever.warlock.procs','warlock-wh-'),
 block('forever.warlock.moving','warlock-wh-'),
 spell('warlock-wh-elements',440892,all(big(),negate({type='DEBUFF',unit='target',spell=440892,anyrank=true}),
  negate(any(own(704),own(702),own(1714),own(18223))))),
 spell('warlock-wh-doom',603,all(big(),bane())),
 spell('warlock-wh-corruption',172,negate(own(172))),
 spell('warlock-wh-agony',980,all(bane(),any(negate(known(18708)),big()))),
 {id='warlock-wh-destruction',type='branch',conditions=destruction,onTrue={
  spell('warlock-wh-destro-immolate',348,negate(own(348))),
  spell('warlock-wh-destro-conflagrate',1293817,all(own(348),{type='DEBUFF_REMAIN',unit='target',spell=348,anyrank=true,owndebuff=true,operator='LESSTHANOREQUALS',value=3})),
  {id='warlock-wh-destro-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
   block('forever.warlock.wand','warlock-wh-destro-'),
  }},
 },onFalse={
  {id='warlock-wh-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
   spell('warlock-wh-solo-drain',689),
   block('forever.warlock.wand','warlock-wh-solo-'),
  }},
 }},
 spell('warlock-wh-bolt',686),
 }},
}))
