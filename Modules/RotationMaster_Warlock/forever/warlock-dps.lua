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
local function havoc()return any(own(1324473),own(1225228))end
local function sacrificed()return any(buff(18789),buff(18790),buff(18791),buff(18792))end
local function pact()return all(known(19028),{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=40})end
local function summon()return all(negate({type='PET'}),any(negate(combat()),buff(18708)),any(negate(sacrificed()),pact()))end
local function ownCurse()return any(own(704),own(702),own(1714),own(18223))end
assert(addon:RegisterDefaultRotation({
 format='RotationMaster',schemaVersion=1,id='rm.forever.warlock.dps',revision=6,
 blocks={['forever.warlock.boundaries']=3,['forever.warlock.upkeep']=2,['forever.warlock.procs']=1,
  ['forever.warlock.moving']=3,['forever.warlock.aoe']=2,['forever.warlock.wand']=2},
 nameKey='Default.Forever.Warlock.DPS.Name',descriptionKey='Default.Forever.Warlock.DPS.Description',
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
  spell('warlock-summon-succubus',712,summon()),
  spell('warlock-summon-voidwalker',697,all(negate(known(712)),summon())),
  spell('warlock-summon-imp',688,all(negate(known(712)),negate(known(697)),summon())),
  spell('warlock-amplify-curse',18288,all(combat(),big(),negate(own(980)))),
  spell('warlock-havoc-reminder',1225228,all(combat(),{type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=2},negate(havoc())))},
 rotation={
 block('forever.warlock.boundaries','warlock-'),
 {id='warlock-pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('warlock-pull-incinerate',412758),
  spell('warlock-pull-bolt',686,known(1293817)),
  spell('warlock-pull-immolate',348,negate(own(348))),
  spell('warlock-pull-agony',980,negate(own(980))),
  {id='warlock-pull-stop',type='stop',suppress_attack=true,conditions={}},
 }},
 block('forever.warlock.procs','warlock-'),
 block('forever.warlock.moving','warlock-'),
 block('forever.warlock.aoe','warlock-'),
 spell('warlock-doom',603,all(big(),negate(havoc()))),
 spell('warlock-agony',980,all(negate(own(980)),negate(own(603)),negate(havoc()))),
 spell('warlock-elements',440892,all(any({type='GROUP'},big()),negate({type='DEBUFF',unit='target',spell=440892,anyrank=true}),negate(ownCurse()))),
 spell('warlock-immolate',348,negate(own(348))),
 spell('warlock-corruption',172,all(negate(own(172)),negate(all(known(1293817),{type='GROUP'})))),
 spell('warlock-siphon-life',18265,negate(own(18265))),
 spell('warlock-conflagrate',1293817,all(own(348),any(known(412758),{type='DEBUFF_REMAIN',unit='target',spell=348,anyrank=true,owndebuff=true,operator='LESSTHANOREQUALS',value=3}))),
 spell('warlock-shadowburn',17877,all(known(412758),{type='CARRYING',item={6265},operator='GREATERTHANOREQUALS',value=2})),
 {id='warlock-solo',type='branch',conditions={type='GROUP'},onTrue={},onFalse={
  spell('warlock-solo-wrack',1316697),
  spell('warlock-solo-drain-filler',689,any(known(18708),known(19028),known(18223),known(18265),known(1316697))),
  block('forever.warlock.wand','warlock-solo-'),
 }},
 spell('warlock-incinerate',412758),
 spell('warlock-bolt',686),
 }},
}))
