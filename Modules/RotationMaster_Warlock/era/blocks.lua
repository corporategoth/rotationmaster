-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Classic Era Warlock blocks, vanilla and Season of Discovery (Built In composition;
-- authoring-time only). Consumers: rm.era.warlock.dps, .dps.warcrafttavern, .dps.icyveins and
-- rm.sod.warlock.tank, .fire, .fire.icyveins, .shadow, .shadow.wowsims. A content change needs a
-- block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research era/warlock.md. Talent positions
-- (tier, then column; verify in game): Affliction 2 Improved Corruption, 4 Improved Drain Soul.
-- Soul Shards are bag items (CARRYING 6265): POINT does not read them on the Era client.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function group()return{type='GROUP'}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function mana(op,v)return{type='MANAPCT',unit='player',operator=op,value=v}end
local function talent(tree,index,value)return{type='TALENT',layout='tree',tree=tree,talent=index,operator='GREATERTHANOREQUALS',value=value}end
local function shards(op,v)return{type='CARRYING',item={6265},operator=op,value=v}end
local function lifetime(op,n)return{type='TT_HEALTH',unit='target',health=0,operator=op,value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function item(id,items,conditions)return{id=id,type='item',action=items,conditions=conditions}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or {}}end
local function block(id,name,prefix)return{id=id,type='block',block=name,prefix=prefix}end
local big=any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='CLASSIFICATION',unit='target',value='elite'})
local raid={type='INSTANCE',value='raid'}
local curses={980,603,1490,17862,704,1714,702,18223}
local function ownCurse()local list={};for i,id in ipairs(curses)do list[i]=own(id)end;return{type='OR',value=list}end
local sacrificed={type='OR',value={buff(18789),buff(18790),buff(18791),buff(18792)}}
-- Healthstones, Major to Minor, Improved variants beside each.
local healthstones={19013,19012,9421,19011,19010,5510,19009,19008,5509,19007,19006,5511,19005,19004,5512}
-- Manual casts and channels (Drain Life, Drain Soul, Hellfire, Rain of Fire, Health Funnel) run to
-- the end; no attackable target, or one someone else is fighting while you are not, ends advice.
assert(addon:RegisterDefaultBlock({id='era.warlock.boundaries',revision=3,families={'era'},class='WARLOCK',steps={
 stop('cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},negate(all({type='ATTACKABLE',unit='target'},any(combat(),negate({type='COMBAT',unit='target'}),group()))))),
}}))
-- Nightfall's Shadow Trance makes the next Shadow Bolt instant; it expires, so it comes first.
assert(addon:RegisterDefaultBlock({id='era.warlock.procs',revision=1,families={'era'},class='WARLOCK',steps={
 spell('shadow-trance',686,buff(17941)),
}}))
-- A boss about to die (group): Shadowburn in its last 1.5 seconds, Searing Pain in its last 3.5.
assert(addon:RegisterDefaultBlock({id='era.warlock.group-finish',revision=1,families={'era'},class='WARLOCK',steps={
 spell('group-shadowburn',17877,all(group(),lifetime('LESSTHAN',1.5))),
 spell('group-searing-pain',5676,all(group(),lifetime('LESSTHAN',3.5))),
}}))
-- A dying solo target gets no new DoTs: Drain Soul for a shard (or Improved Drain Soul mana),
-- else Shadowburn or Conflagrate, else the wand, then stop.
assert(addon:RegisterDefaultBlock({id='era.warlock.dying',revision=2,families={'era'},class='WARLOCK',steps={
 {id='dying',type='branch',conditions=all(negate(group()),negate(big),{type='HEALTHPCT',unit='target',operator='LESSTHAN',value=.15}),onFalse={},onTrue={
  spell('drain-soul',1120,any(shards('LESSTHAN',3),talent(1,4,1))),
  spell('shadowburn',17877),
  spell('conflagrate',17962,own(348)),
  stop('dying-wanding',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),
  spell('dying-wand',5019),
  stop('dying-stop'),
 }},
}}))
-- One curse per Warlock per target. Raid: Curse of Shadow for a Shadow build, Curse of the
-- Elements, each only if nobody's is up; Doom on a long fight; else Agony. Five-man: Doom on a long
-- elite fight, else Agony. Solo: Agony. Recklessness, Tongues and Weakness stay manual.
local longFight=lifetime('GREATERTHAN',60)
assert(addon:RegisterDefaultBlock({id='era.warlock.curse',revision=2,families={'era'},class='WARLOCK',steps={
 {id='curse-needed',type='branch',conditions=ownCurse(),onTrue={},onFalse={
  {id='curse-raid',type='branch',conditions=raid,onFalse={},onTrue={
   spell('shadow',17862,all(negate({type='DEBUFF',unit='target',spell=17862,anyrank=true}),any(known(18788),negate({type='PRIMARY_TALENT_TREE',tree=3})))),
   spell('elements',1490,negate({type='DEBUFF',unit='target',spell=1490,anyrank=true})),
  }},
  spell('doom',603,all(group(),big,longFight)),
  spell('agony',980),
 }},
}}))
-- Moving: instants only, then stop. Corruption counts only with Improved Corruption 5/5.
assert(addon:RegisterDefaultBlock({id='era.warlock.moving',revision=2,families={'era'},class='WARLOCK',steps={
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('moving-corruption',172,all(talent(1,2,5),negate(own(172)))),
  block('moving-curse','era.warlock.curse','moving-'),
  spell('moving-siphon',18265,negate(own(18265))),
  spell('moving-drain-life',403677,negate(own(403677))),
  spell('moving-tap',1454,all(mana('LESSTHAN',.9),health('GREATERTHAN',.5))),
  spell('moving-shadowburn',17877,shards('GREATERTHANOREQUALS',3)),
  spell('moving-death-coil',6789,all(negate(group()),health('LESSTHAN',.5))),
  stop('moving-stop')}},
}}))
-- Three or more engaged enemies: Hellfire with three near you and half health, else Rain of Fire
-- (Lake of Fire's instant version once engraved); then the single-target list spreads DoTs.
assert(addon:RegisterDefaultBlock({id='era.warlock.aoe',revision=1,families={'era'},class='WARLOCK',steps={
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  spell('lake-of-fire',460692),
  spell('hellfire',1949,all({type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=3},health('GREATERTHAN',.5))),
  spell('rain-of-fire',5740,negate(known(460692))),
 }},
}}))
-- Solo sustain: Dark Pact from a full pet, Life Tap when healthy, Drain Life when hurt, the wand.
assert(addon:RegisterDefaultBlock({id='era.warlock.sustain',revision=3,families={'era'},class='WARLOCK',steps={
 {id='solo',type='branch',conditions=group(),onTrue={},onFalse={
  spell('dark-pact',18220,all(mana('LESSTHAN',.6),{type='MANAPCT',unit='pet',operator='GREATERTHAN',value=.4})),
  spell('life-tap',1454,all(mana('LESSTHAN',.6),health('GREATERTHAN',.75))),
  spell('drain-life',689,all(health('LESSTHAN',.6),negate(known(403677)))),
  stop('wanding',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),
  spell('wand',5019),
 }},
}}))
-- Filler: Shadow Bolt; Life Tap when nothing else can be cast. Casters never melee.
assert(addon:RegisterDefaultBlock({id='era.warlock.filler',revision=2,families={'era'},class='WARLOCK',steps={
 spell('bolt',686),
 spell('tap',1454,health('GREATERTHAN',.4)),
 stop('exhausted'),
}}))
-- Armor: Fel Armor (SoD) over Demon Armor (20) over Demon Skin. A learned better armor replaces
-- Skin but never a Demon Armor you chose, and an unready preferred armor never licenses a fallback.
local function missing(id)return negate(buff(id))end
assert(addon:RegisterDefaultBlock({id='era.warlock.armor',revision=1,families={'era'},class='WARLOCK',steps={
 spell('fel-armor',403619,all(known(403619),missing(403619),missing(706))),
 spell('demon-armor',706,all(negate(known(403619)),known(706),missing(706),missing(403619))),
 spell('demon-skin',687,all(negate(known(403619)),negate(known(706)),missing(706),missing(687),missing(403619))),
}}))
-- Pets out of combat (Fel Domination in combat), never after a sacrifice: a Felguard once
-- engraved, else the Voidwalker solo, the Succubus in a group for Demonic Sacrifice, else the Imp.
local summon=all(negate({type='PET'}),negate(sacrificed),negate(combat()))
assert(addon:RegisterDefaultBlock({id='era.warlock.pets',revision=1,families={'era'},class='WARLOCK',steps={
 spell('felguard',427733,summon),
 spell('voidwalker',697,all(summon,negate(group()),negate(known(427733)))),
 spell('succubus',712,all(summon,group(),known(18788),negate(known(427733)))),
 spell('imp',688,all(summon,negate(known(427733)),any(all(group(),negate(known(18788))),negate(known(697))))),
 spell('fel-domination',18708,all(combat(),negate({type='PET'}),negate(sacrificed))),
 spell('demonic-sacrifice',18788,all({type='PET'},group(),negate(sacrificed),negate(known(427733)))),
}}))
-- Safety and talents: Amplify Curse before Agony, Voidwalker Sacrifice and a Healthstone when low,
-- Health Funnel for a dying pet. (Curse of Recklessness on a runner needs MobInfo2's RUNNER, which
-- would leave the whole premade unresolved without that addon, so it stays manual.)
assert(addon:RegisterDefaultBlock({id='era.warlock.safety',revision=1,families={'era'},class='WARLOCK',steps={
 spell('amplify-curse',18288,all(combat(),{type='ATTACKABLE',unit='target'},negate(own(980)))),
 spell('voidwalker-sacrifice',7812,all(combat(),{type='PETSPELL_AVAIL',spell=7812},health('LESSTHAN',.35))),
 item('healthstone',healthstones,all(combat(),health('LESSTHAN',.45))),
 spell('health-funnel',755,all(combat(),negate(group()),{type='PET'},{type='HEALTHPCT',unit='pet',operator='LESSTHAN',value=.3},health('GREATERTHAN',.6))),
}}))
