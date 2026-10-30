-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- WoW Forever Warlock, levels 1–60, all three trees (the recommended premade).
-- One pack: every tree runs pet + Bane + Curse + DoTs + filler, and the tree steps are gated
-- by talent-taught spells (Demonic Brand/Fel Domination, Decimation, Conflagrate, Incinerate,
-- Wrack). Pull with Immolate and Agony (Destruction precasts Shadow Bolt); procs; Demonic Brand;
-- instants while moving; packs; Bane of Doom on bosses else Agony; Curse of the Elements in
-- groups and on elites; Immolate, Corruption (not for Destruction in groups), Siphon Life;
-- Conflagrate and Shadowburn; a solo Wrack / Drain Life (with a drain talent) / wand filler;
-- Incinerate or Shadow Bolt. Health and mana are secret on Forever, so the execute window, Life
-- Tap and health-driven Drain Life are left to the player.
-- Shared parts: Defaults/blocks/forever-warlock.lua. Left manual: sending the pet in, which
-- demon to keep (Succubus, else Voidwalker, else Imp is only the default reminder), Curse of
-- Recklessness/Tongues/Weakness, Fear, Healthstones, multi-dotting other targets and putting
-- Bane of Havoc on a second enemy (only reminded).
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function block(name,prefix)return{id=prefix..'ref-'..name:match('[^.]+$'),type='block',block=name,prefix=prefix}end
local function big()return BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})end
local function havoc()return BuiltinConditions.any(own(1324473),own(1225228))end
local function sacrificed()return BuiltinConditions.any(buff(18789),buff(18790),buff(18791),buff(18792))end
local function pact()return BuiltinConditions.all(BuiltinConditions.known(19028),{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=40})end
local function summon()return BuiltinConditions.all(BuiltinConditions.negate({type='PET'}),BuiltinConditions.any(BuiltinConditions.negate(BuiltinConditions.combat()),buff(18708)),BuiltinConditions.any(BuiltinConditions.negate(sacrificed()),pact()))end
local function ownCurse()return BuiltinConditions.any(own(704),own(702),own(1714),own(18223))end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warlock.dps',revision=6,
 blocks={['forever.warlock.boundaries']=3,['forever.warlock.upkeep']=2,['forever.warlock.procs']=1,
  ['forever.warlock.moving']=3,['forever.warlock.aoe']=2,['forever.warlock.wand']=2},
 applicability={families={'forever'},actionContext='player',class='WARLOCK'},
 tags={'dps','ranged','caster','leveling','endgame','aoe','icy-veins','wowhead','method'},
 sources={{url='https://www.icy-veins.com/wow-forever/affliction-warlock-leveling',title='Icy Veins: Forever Affliction Warlock leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/demonology-warlock-leveling',title='Icy Veins: Forever Demonology Warlock leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.icy-veins.com/wow-forever/destruction-warlock-leveling',title='Icy Veins: Forever Destruction Warlock leveling',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://www.wowhead.com/forever/guide/classes/warlock/affliction/level-30-dps-overview',title='Wowhead: Forever level 30 Affliction Warlock',reviewedAt='2026-10-23',revision='2026-10-09'},
 {url='https://www.wowhead.com/forever/guide/classes/warlock/demonology/level-30-dps-overview',title='Wowhead: Forever level 30 Demonology Warlock',reviewedAt='2026-10-23',revision='2026-10-09'},
 {url='https://www.method.gg/wow-forever/wow-forever-warlock-leveling-guide-and-talents',title='Method: Forever Warlock leveling guide and talents',reviewedAt='2026-10-23',revision='2026-10-17'},
 {url='https://worldofwarcraft.blizzard.com/en-us/news/24310968',title='Blizzard: Forever class deep dives, Rogue and Warlock',reviewedAt='2026-10-23',revision='2026-10-07'}},
 body={priority=10,
 cooldowns={block('forever.warlock.upkeep','warlock-'),
  BuiltinConditions.spell('warlock-summon-succubus',712,summon()),
  BuiltinConditions.spell('warlock-summon-voidwalker',697,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(712)),summon())),
  BuiltinConditions.spell('warlock-summon-imp',688,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(712)),BuiltinConditions.negate(BuiltinConditions.known(697)),summon())),
  BuiltinConditions.spell('warlock-amplify-curse',18288,BuiltinConditions.all(BuiltinConditions.combat(),big(),BuiltinConditions.negate(own(980)))),
  BuiltinConditions.spell('warlock-havoc-reminder',1225228,BuiltinConditions.all(BuiltinConditions.combat(),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},BuiltinConditions.negate(havoc())))},
 rotation={
 block('forever.warlock.boundaries','warlock-'),
 {id='warlock-pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('warlock-pull-incinerate',412758),
  BuiltinConditions.spell('warlock-pull-bolt',686,BuiltinConditions.known(1293817)),
  BuiltinConditions.spell('warlock-pull-immolate',348,BuiltinConditions.negate(own(348))),
  BuiltinConditions.spell('warlock-pull-agony',980,BuiltinConditions.negate(own(980))),
  {id='warlock-pull-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 block('forever.warlock.procs','warlock-'),
 block('forever.warlock.moving','warlock-'),
 block('forever.warlock.aoe','warlock-'),
 BuiltinConditions.spell('warlock-doom',603,BuiltinConditions.all(big(),BuiltinConditions.negate(havoc()))),
 BuiltinConditions.spell('warlock-agony',980,BuiltinConditions.all(BuiltinConditions.negate(own(980)),BuiltinConditions.negate(own(603)),BuiltinConditions.negate(havoc()))),
 BuiltinConditions.spell('warlock-elements',440892,BuiltinConditions.all(BuiltinConditions.any({type='GROUP'},big()),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=440892,anyrank=true}),BuiltinConditions.negate(ownCurse()))),
 BuiltinConditions.spell('warlock-immolate',348,BuiltinConditions.negate(own(348))),
 BuiltinConditions.spell('warlock-corruption',172,BuiltinConditions.all(BuiltinConditions.negate(own(172)),BuiltinConditions.negate(BuiltinConditions.all(BuiltinConditions.known(1293817),{type='GROUP'})))),
 BuiltinConditions.spell('warlock-siphon-life',18265,BuiltinConditions.negate(own(18265))),
 BuiltinConditions.spell('warlock-conflagrate',1293817,BuiltinConditions.all(own(348),BuiltinConditions.any(BuiltinConditions.known(412758),{type='DEBUFF_REMAIN',unit='target',spell=348,anyrank=true,owndebuff=true,operator='LESSTHANOREQUALS',value=3}))),
 BuiltinConditions.spell('warlock-shadowburn',17877,BuiltinConditions.all(BuiltinConditions.known(412758),{type='CARRYING',item={6265},operator='GREATERTHANOREQUALS',value=2})),
 {id='warlock-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
  BuiltinConditions.spell('warlock-solo-wrack',1316697),
  BuiltinConditions.spell('warlock-solo-drain-filler',689,BuiltinConditions.any(BuiltinConditions.known(18708),BuiltinConditions.known(19028),BuiltinConditions.known(18223),BuiltinConditions.known(18265),BuiltinConditions.known(1316697))),
  block('forever.warlock.wand','warlock-solo-'),
 }},
 BuiltinConditions.spell('warlock-incinerate',412758),
 BuiltinConditions.spell('warlock-bolt',686),
 }},
}))
