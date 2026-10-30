-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Warlock, Icy Veins leveling guides (player-chosen variant, all three trees).
-- Same switch as the recommended Warlock premade, lower priority, off by default. Differs from
-- the default: the wand is the solo filler (Wrack only once known and only in groups),
-- Voidwalker is the default pet, the Affliction and Destruction builds sacrifice their demon and
-- play without one (from 41 and 55), Demonology demotes Immolate to a filler, and Destruction
-- puts Bane of Havoc on the durable enemy of a pack. Health, mana and time to die are secret or
-- unavailable on Forever, so its health-driven Drain Life and Life Tap and its targets-that-live
-- DoT rule are left out. Trees by talent-taught spell: Conflagrate (Destruction), Fel Domination
-- (Demonology), else Affliction. Shared parts: Defaults/blocks/forever-warlock.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function level(n)return{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=n}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
local function havoc()return BuiltinConditions.any(own(1324473),own(1225228))end
local function sacrificed()return BuiltinConditions.any(buff(18789),buff(18790),buff(18791),buff(18792))end
local function pact()return BuiltinConditions.all(BuiltinConditions.known(19028),level(40))end
local function summon()return BuiltinConditions.all(BuiltinConditions.negate({type='PET'}),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.combat()),buff(18708)),BuiltinConditions.any(BuiltinConditions.negate(sacrificed()),pact()))end
local function bane()return BuiltinConditions.all(BuiltinConditions.negate(own(980)),BuiltinConditions.negate(own(603)),BuiltinConditions.negate(havoc()))end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warlock.dps.icyveins',revision=6,
 blocks={['forever.warlock.boundaries']=3,['forever.warlock.upkeep']=2,['forever.warlock.procs']=1,
  ['forever.warlock.moving']=3,['forever.warlock.aoe']=2,['forever.warlock.wand']=2},
 applicability={families={'forever'},actionContext='player',class='WARLOCK'},
 tags={'dps','ranged','caster','leveling','endgame','aoe','icy-veins'},
 sources={{url='https://www.icy-veins.com/wow-forever/affliction-warlock-leveling',title='Icy Veins: Forever Affliction Warlock leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/demonology-warlock-leveling',title='Icy Veins: Forever Demonology Warlock leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/destruction-warlock-leveling',title='Icy Veins: Forever Destruction Warlock leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/affliction-warlock-ranged-dps-pve-guide',title='Icy Veins: Forever Affliction Warlock PvE guide',reviewedAt='2026-10-23',revision='2026-10-17'}},
 body={priority=6,disabled=true,
 cooldowns={block('forever.warlock.upkeep','warlock-iv-'),
  BuiltinConditions.spell('warlock-iv-summon-voidwalker',697,summon()),
  BuiltinConditions.spell('warlock-iv-summon-succubus',712,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(697)),summon())),
  BuiltinConditions.spell('warlock-iv-summon-imp',688,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(697)),BuiltinConditions.negate(BuiltinConditions.known(712)),summon())),
  BuiltinConditions.spell('warlock-iv-petless-sacrifice',18788,BuiltinConditions.all({type='PET'},BuiltinConditions.negate(sacrificed()),BuiltinConditions.negate(BuiltinConditions.known(18708)),BuiltinConditions.any(BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(1293817)),level(41)),level(55)))),
  BuiltinConditions.spell('warlock-iv-amplify-curse',18288,BuiltinConditions.all(BuiltinConditions.combat(),big(),BuiltinConditions.negate(own(980))))},
 rotation={
 block('forever.warlock.boundaries','warlock-iv-'),
 {id='warlock-iv-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('warlock-iv-pull-bolt',686,BuiltinConditions.known(1293817)),
  BuiltinConditions.spell('warlock-iv-pull-immolate',348,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(18708)),BuiltinConditions.negate(own(348)))),
  {id='warlock-iv-pull-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 block('forever.warlock.procs','warlock-iv-'),
 block('forever.warlock.moving','warlock-iv-'),
 BuiltinConditions.spell('warlock-iv-havoc',1225228,BuiltinConditions.all(BuiltinConditions.known(1293817),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},big(),BuiltinConditions.negate(havoc()))),
 block('forever.warlock.aoe','warlock-iv-'),
 BuiltinConditions.spell('warlock-iv-elements',440892,BuiltinConditions.all(BuiltinConditions.any({type='GROUP'},big()),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=440892,anyrank=true}),
  BuiltinConditions.negate(BuiltinConditions.any(own(704),own(702),own(1714),own(18223))))),
 {id='warlock-iv-destruction',type='branch',conditions=BuiltinConditions.known(1293817),onTrue={
  BuiltinConditions.spell('warlock-iv-destro-immolate',348,BuiltinConditions.negate(own(348))),
  BuiltinConditions.spell('warlock-iv-destro-agony',980,bane()),
  BuiltinConditions.spell('warlock-iv-destro-conflagrate',1293817,BuiltinConditions.all(own(348),BuiltinConditions.any(BuiltinConditions.known(412758),{type='DEBUFF_REMAIN',unit='target',spell=348,anyrank=true,owndebuff=true,operator='LESSTHANOREQUALS',value=3}))),
  BuiltinConditions.spell('warlock-iv-destro-shadowburn',17877,BuiltinConditions.known(412758)),
 },onFalse={
  {id='warlock-iv-demonology',type='branch',conditions=BuiltinConditions.known(18708),onTrue={
   BuiltinConditions.spell('warlock-iv-demo-agony',980,bane()),
   BuiltinConditions.spell('warlock-iv-demo-corruption',172,BuiltinConditions.negate(own(172))),
  },onFalse={
   BuiltinConditions.spell('warlock-iv-aff-agony',980,bane()),
   BuiltinConditions.spell('warlock-iv-aff-siphon-life',18265,BuiltinConditions.negate(own(18265))),
   BuiltinConditions.spell('warlock-iv-aff-corruption',172,BuiltinConditions.negate(own(172))),
  }},
 }},
 {id='warlock-iv-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
  block('forever.warlock.wand','warlock-iv-solo-'),
 }},
 BuiltinConditions.spell('warlock-iv-incinerate',412758,own(348)),
 BuiltinConditions.spell('warlock-iv-wrack',1316697),
 BuiltinConditions.spell('warlock-iv-demo-immolate',348,BuiltinConditions.all(BuiltinConditions.known(18708),BuiltinConditions.negate(own(348)))),
 BuiltinConditions.spell('warlock-iv-bolt',686),
 }},
}))
