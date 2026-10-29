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
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
local function sacrificed()return BuiltinConditions.any(buff(18789),buff(18790),buff(18791),buff(18792))end
local function pact()return BuiltinConditions.all(BuiltinConditions.known(19028),{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=40})end
local function summon()return BuiltinConditions.all(BuiltinConditions.negate({type='PET'}),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.combat()),buff(18708)),BuiltinConditions.any(BuiltinConditions.negate(sacrificed()),pact()))end
local function bane()return BuiltinConditions.all(BuiltinConditions.negate(own(980)),BuiltinConditions.negate(own(603)),BuiltinConditions.negate(BuiltinConditions.any(own(1324473),own(1225228))))end
local destruction=BuiltinConditions.known(1293817)
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warlock.dps.wowhead',revision=6,
 blocks={['forever.warlock.boundaries']=3,['forever.warlock.upkeep']=2,['forever.warlock.procs']=1,
  ['forever.warlock.moving']=3,['forever.warlock.wand']=2},
 applicability={families={'forever'},actionContext='player',class='WARLOCK'},
 tags={'dps','ranged','caster','leveling','wowhead'},
 sources={{url='https://www.wowhead.com/forever/guide/classes/warlock/affliction/level-30-dps-overview',title='Wowhead: Forever level 30 Affliction Warlock',reviewedAt='2026-10-23',revision='2026-10-09'},
 {url='https://www.wowhead.com/forever/guide/classes/warlock/demonology/level-30-dps-overview',title='Wowhead: Forever level 30 Demonology Warlock',reviewedAt='2026-10-23',revision='2026-10-09'},
 {url='https://www.wowhead.com/forever/guide/classes/warlock/destruction/level-30-dps-overview',title='Wowhead: Forever level 30 Destruction Warlock',reviewedAt='2026-10-23',revision='2026-10-09'}},
 body={priority=5,disabled=true,
 cooldowns={block('forever.warlock.upkeep','warlock-wh-'),
  BuiltinConditions.spell('warlock-wh-summon-destro-voidwalker',697,BuiltinConditions.all(destruction,summon())),
  BuiltinConditions.spell('warlock-wh-summon-succubus',712,BuiltinConditions.all(BuiltinConditions.negate(destruction),summon())),
  BuiltinConditions.spell('warlock-wh-summon-voidwalker',697,BuiltinConditions.all(BuiltinConditions.negate(destruction),BuiltinConditions.negate(BuiltinConditions.known(712)),summon())),
  BuiltinConditions.spell('warlock-wh-summon-imp',688,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(712)),BuiltinConditions.negate(BuiltinConditions.known(697)),summon())),
  BuiltinConditions.spell('warlock-wh-amplify-curse',18288,BuiltinConditions.combat())},
 rotation={
 block('forever.warlock.boundaries','warlock-wh-'),
 {id='warlock-wh-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('warlock-wh-pull-corruption',172,BuiltinConditions.negate(own(172))),
  BuiltinConditions.spell('warlock-wh-pull-agony',980,BuiltinConditions.all(bane(),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(18708)),big()))),
  BuiltinConditions.spell('warlock-wh-pull-immolate',348,BuiltinConditions.all(destruction,BuiltinConditions.negate(own(348)))),
  {id='warlock-wh-pull-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 block('forever.warlock.procs','warlock-wh-'),
 block('forever.warlock.moving','warlock-wh-'),
 BuiltinConditions.spell('warlock-wh-elements',440892,BuiltinConditions.all(big(),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=440892,anyrank=true}),
  BuiltinConditions.negate(BuiltinConditions.any(own(704),own(702),own(1714),own(18223))))),
 BuiltinConditions.spell('warlock-wh-doom',603,BuiltinConditions.all(big(),bane())),
 BuiltinConditions.spell('warlock-wh-corruption',172,BuiltinConditions.negate(own(172))),
 BuiltinConditions.spell('warlock-wh-agony',980,BuiltinConditions.all(bane(),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.known(18708)),big()))),
 {id='warlock-wh-destruction',type='branch',conditions=destruction,onTrue={
  BuiltinConditions.spell('warlock-wh-destro-immolate',348,BuiltinConditions.negate(own(348))),
  BuiltinConditions.spell('warlock-wh-destro-conflagrate',1293817,BuiltinConditions.all(own(348),{type='DEBUFF_REMAIN',unit='target',spell=348,anyrank=true,owndebuff=true,operator='LESSTHANOREQUALS',value=3})),
  {id='warlock-wh-destro-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
   block('forever.warlock.wand','warlock-wh-destro-'),
  }},
 },onFalse={
  {id='warlock-wh-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
   BuiltinConditions.spell('warlock-wh-solo-drain',689),
   block('forever.warlock.wand','warlock-wh-solo-'),
  }},
 }},
 BuiltinConditions.spell('warlock-wh-bolt',686),
 }},
}))
