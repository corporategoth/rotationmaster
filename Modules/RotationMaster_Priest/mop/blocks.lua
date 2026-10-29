-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Priest blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.priest.{shadow,shadow.warcrafttavern,discipline,holy,holy.icyveins,unspecialized}. A content
-- change needs a block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research progression/priest.md.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function combat()return{type='COMBAT',unit='player'}end
local function own(id)return{type='BUFF',unit='player',spell=id,ownbuff=true}end
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=n}end
local function health(unit,op,n)return{type='HEALTHPCT',unit=unit,operator=op,value=n}end
local function mana(op,n)return{type='MANAPCT',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function classified(kind)return{type='CLASSIFICATION',unit='target',value=kind}end
local function hurt(n,below)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=40,healthoperator='LESSTHAN',health=below,operator='GREATERTHANOREQUALS',value=n}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='stop',suppress_attack=true,conditions=conditions or {}}end
-- The target lives long enough for a DoT: healthy, or forecast to live n seconds (health first: always readable).
local function lives(n)return any(health('target','GREATERTHANOREQUALS',.35),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=n})end
local worth=any(classified('worldboss'),classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=15})
local execute=health('target','LESSTHAN',.2)
-- Every priest: Inner Fire unless you chose Inner Will, Power Word: Fortitude between pulls.
assert(addon:RegisterDefaultBlock({
 id='mop.priest.upkeep',revision=1,families={'progression'},class='PRIEST',steps={
 spell('inner-fire',588,all(negate(own(588)),negate(own(73413)))),
 spell('fortitude',21562,all(negate(combat()),negate({type='BUFF',unit='player',spell=21562}))),
}}))
-- Healers and the unspecialized pack: any cast or channel of yours stops the list.
assert(addon:RegisterDefaultBlock({
 id='mop.priest.healer-boundaries',revision=2,families={'progression'},class='PRIEST',steps={
 stop('manual',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- Healer cooldowns (Hekili thresholds, RM policy): Shadowfiend or Mindbender for mana, Power Infusion when three
-- allies are hurt, Hymn of Hope (off: a raid decision).
assert(addon:RegisterDefaultBlock({
 id='mop.priest.healer-cooldowns',revision=1,families={'progression'},class='PRIEST',steps={
 spell('shadowfiend',34433,all(combat(),mana('LESSTHAN',.8))),
 spell('mindbender',123040,all(combat(),mana('LESSTHAN',.8))),
 spell('power-infusion',10060,all(combat(),hurt(3,.7))),
 {id='hymn-of-hope',type='spell',action=64901,ranked=false,disabled=true,conditions=all(combat(),mana('LESSTHAN',.2))},
}}))
-- Holy's damage arm (solo questing; MaxDps' Holy list): Holy Word: Chastise outside Serenity and Sanctuary,
-- Solace or Holy Fire, Shadow Word: Pain solo on a target that lives, the tier-6 talent on three enemies, Smite.
assert(addon:RegisterDefaultBlock({
 id='mop.priest.holy-damage',revision=2,families={'progression'},class='PRIEST',steps={
 stop('no-enemy',negate({type='ATTACKABLE',unit='target'})),
 spell('chastise',88625,all(negate(own(81208)),negate(own(81206)))),
 spell('solace',129250),
 spell('holy-fire',14914,negate({type='TALENT',layout='grid',value=9})),
 spell('pain',589,all(negate({type='GROUP'}),negate(dot(589)),lives(12))),
 spell('halo',120517,enemies('GREATERTHANOREQUALS',3)),
 spell('cascade',121135,enemies('GREATERTHANOREQUALS',3)),
 spell('divine-star',110744,enemies('GREATERTHANOREQUALS',3)),
 spell('smite',585),
 stop('damage-stop'),
}}))
-- Shadow boundaries, pull, movement and packs, shared by both Shadow premades. A cast stops the list; a channel
-- stops it too unless it is Mind Flay (or Mind Flay: Insanity) and either Mind Blast (or Shadow Word: Death on a
-- target below 20%) is ready to clip it (Icy Veins) or its second of three ticks is done (simulator clips at two
-- ticks; ticks are evenly spaced, so that is two thirds of the channel whatever the haste). Out of combat: Mind Spike, Mind Blast, Vampiric Touch, Shadow Word: Pain, Mind Flay, then
-- stop. Moving: instants only (Hekili's moving list). Five or more engaged enemies: the tier-6 talent, DoTs on
-- the current target, Mind Sear from 76 (guide consensus), then stop; before Mind Sear the single-target list runs.
local flaying=any({type='CHANNELING_SPELL',unit='player',spell=15407},{type='CHANNELING_SPELL',unit='player',spell=129197})
local clip=all(flaying,any({type='SPELL_AVAIL',spell=8092},all(execute,{type='SPELL_AVAIL',spell=32379}),
 {type='CHANNELING_PROGRESS',unit='player',operator='GREATERTHANOREQUALS',value=.67}))
assert(addon:RegisterDefaultBlock({
 id='mop.priest.shadow-shell',revision=5,families={'progression'},class='PRIEST',steps={
 stop('cast',any({type='CASTING',unit='player'},all({type='CHANNELING',unit='player'},negate(clip)),negate({type='ATTACKABLE',unit='target'}))),
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  spell('pull-spike',73510),
  spell('pull-blast',8092),
  spell('pull-touch',34914),
  spell('pull-pain',589),
  spell('pull-flay',15407),
  stop('pull-stop'),
 }},
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('moving-plague',2944,{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=3}),
  spell('moving-death',32379,execute),
  spell('moving-insight',8092,own(124430)),
  spell('moving-surge',73510,own(87160)),
  spell('moving-halo',120517,all(negate({type='DISTANCE',unit='target',value=15}),{type='DISTANCE',unit='target',value=30})),
  spell('moving-cascade',121135,negate({type='DISTANCE',unit='target',value=10})),
  spell('moving-divine-star',110744,{type='DISTANCE',unit='target',value=24}),
  spell('moving-pain',589),
  stop('moving-stop'),
 }},
 {id='aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  spell('aoe-halo',120517),
  spell('aoe-cascade',121135),
  spell('aoe-divine-star',110744),
  spell('aoe-touch',34914,all(negate(dot(34914)),lives(10))),
  spell('aoe-pain',589,all(negate(dot(589)),lives(10))),
  spell('aoe-sear',48045),
  stop('aoe-stop',{type='SPELL_KNOWN',spell=48045}),
 }},
}}))
-- Shadow reminders: Shadowform, Silence, Shadowfiend or Mindbender and Power Infusion on long fights (damage
-- cooldowns for Shadow), Vampiric Embrace, Desperate Prayer and Dispersion when low (RM policy), Psychic Scream
-- (off: levelling safety when three enemies are on you).
assert(addon:RegisterDefaultBlock({
 id='mop.priest.shadow-cooldowns',revision=2,families={'progression'},class='PRIEST',steps={
 spell('shadowform',15473,negate({type='FORM',form=15473})),
 spell('silence',15487,any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 spell('shadowfiend',34433,all(combat(),worth)),
 spell('mindbender',123040,all(combat(),worth)),
 spell('power-infusion',10060,all(combat(),worth)),
 spell('vampiric-embrace',15286,all(combat(),health('player','LESSTHANOREQUALS',.4))),
 spell('desperate-prayer',19236,health('player','LESSTHAN',.35)),
 spell('dispersion',47585,all(combat(),any(mana('LESSTHAN',.15),health('player','LESSTHAN',.25)))),
 {id='psychic-scream',type='spell',action=8122,ranked=false,disabled=true,conditions=all(health('player','LESSTHAN',.5),
  {type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=3})},
}}))
