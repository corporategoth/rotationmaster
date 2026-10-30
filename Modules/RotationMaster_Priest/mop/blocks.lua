-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Mists of Pandaria Classic Priest blocks (Built In composition; authoring-time only).
-- Consumers: rm.mop.priest.{shadow,shadow.warcrafttavern,discipline,holy,holy.icyveins,unspecialized}. A content
-- change needs a block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua. Policy and sources are the consumers'; see
-- premade-research progression/priest.md.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function dot(id)return{type='DEBUFF',unit='target',spell=id,owndebuff=true}end
local function remain(id,n)return{type='DEBUFF_REMAIN',unit='target',spell=id,owndebuff=true,operator='LESSTHAN',value=n}end
local function health(unit,op,n)return{type='HEALTHPCT',unit=unit,operator=op,value=n}end
local function mana(op,n)return{type='MANAPCT',unit='player',operator=op,value=n}end
local function enemies(op,n)return{type='THREAT_COUNT',threat=1,operator=op,value=n}end
local function hurt(n,below)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',distance=40,healthoperator='LESSTHAN',health=below,operator='GREATERTHANOREQUALS',value=n}end
-- The target lives long enough for a DoT: healthy, or forecast to live n seconds (health first: always readable).
local function lives(n)return BuiltinConditions.any(health('target','GREATERTHANOREQUALS',.35),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=n})end
local worth=BuiltinConditions.any(BuiltinConditions.classified('worldboss'),BuiltinConditions.classified('elite'),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=15})
local execute=health('target','LESSTHAN',.2)
-- Every priest: Inner Fire unless you chose Inner Will, Power Word: Fortitude between pulls.
assert(addon:RegisterDefaultBlock({
 id='mop.priest.upkeep',revision=1,families={'progression'},class='PRIEST',steps={
 BuiltinConditions.spell('inner-fire',588,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.ownBuff(588)),BuiltinConditions.negate(BuiltinConditions.ownBuff(73413)))),
 BuiltinConditions.spell('fortitude',21562,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='BUFF',unit='player',spell=21562}))),
}}))
-- Healers and the unspecialized pack: any cast or channel of yours stops the list.
assert(addon:RegisterDefaultBlock({
 id='mop.priest.healer-boundaries',revision=2,families={'progression'},class='PRIEST',steps={
 BuiltinConditions.stop('manual',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
}}))
-- Healer cooldowns (Hekili thresholds, RM policy): Shadowfiend or Mindbender for mana, Power Infusion when three
-- allies are hurt, Hymn of Hope (off: a raid decision).
assert(addon:RegisterDefaultBlock({
 id='mop.priest.healer-cooldowns',revision=1,families={'progression'},class='PRIEST',steps={
 BuiltinConditions.spell('shadowfiend',34433,BuiltinConditions.all(BuiltinConditions.combat(),mana('LESSTHAN',.8))),
 BuiltinConditions.spell('mindbender',123040,BuiltinConditions.all(BuiltinConditions.combat(),mana('LESSTHAN',.8))),
 BuiltinConditions.spell('power-infusion',10060,BuiltinConditions.all(BuiltinConditions.combat(),hurt(3,.7))),
 {id='hymn-of-hope',type='spell',action=64901,ranked=false,disabled=true,conditions=BuiltinConditions.all(BuiltinConditions.combat(),mana('LESSTHAN',.2))},
}}))
-- Holy's damage arm (solo questing; MaxDps' Holy list): Holy Word: Chastise outside Serenity and Sanctuary,
-- Solace or Holy Fire, Shadow Word: Pain solo on a target that lives, the tier-6 talent on three enemies, Smite.
assert(addon:RegisterDefaultBlock({
 id='mop.priest.holy-damage',revision=2,families={'progression'},class='PRIEST',steps={
 BuiltinConditions.stop('no-enemy',BuiltinConditions.negate({type='ATTACKABLE',unit='target'})),
 BuiltinConditions.spell('chastise',88625,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.ownBuff(81208)),BuiltinConditions.negate(BuiltinConditions.ownBuff(81206)))),
 BuiltinConditions.spell('solace',129250),
 BuiltinConditions.spell('holy-fire',14914,BuiltinConditions.negate({type='TALENT',layout='grid',value=9})),
 BuiltinConditions.spell('pain',589,BuiltinConditions.all(BuiltinConditions.negate({type='GROUP'}),BuiltinConditions.negate(dot(589)),lives(12))),
 BuiltinConditions.spell('halo',120517,enemies('GREATERTHANOREQUALS',3)),
 BuiltinConditions.spell('cascade',121135,enemies('GREATERTHANOREQUALS',3)),
 BuiltinConditions.spell('divine-star',110744,enemies('GREATERTHANOREQUALS',3)),
 BuiltinConditions.spell('smite',585),
 BuiltinConditions.stop('damage-stop'),
}}))
-- Shadow boundaries, pull, movement and packs, shared by both Shadow premades. A cast stops the list; a channel
-- stops it too unless it is Mind Flay (or Mind Flay: Insanity) and either Mind Blast (or Shadow Word: Death on a
-- target below 20%) is ready to clip it (Icy Veins) or its second of three ticks is done (simulator clips at two
-- ticks; ticks are evenly spaced, so that is two thirds of the channel whatever the haste). Out of combat: Mind Spike, Mind Blast, Vampiric Touch, Shadow Word: Pain, Mind Flay, then
-- stop. Moving: instants only (Hekili's moving list). Five or more engaged enemies: the tier-6 talent, DoTs on
-- the current target, Mind Sear from 76 (guide consensus), then stop; before Mind Sear the single-target list runs.
local flaying=BuiltinConditions.any({type='CHANNELING_SPELL',unit='player',spell=15407},{type='CHANNELING_SPELL',unit='player',spell=129197})
local clip=BuiltinConditions.all(flaying,BuiltinConditions.any({type='SPELL_AVAIL',spell=8092},BuiltinConditions.all(execute,{type='SPELL_AVAIL',spell=32379}),
 {type='CHANNELING_PROGRESS',unit='player',operator='GREATERTHANOREQUALS',value=.67}))
assert(addon:RegisterDefaultBlock({
 id='mop.priest.shadow-shell',revision=5,families={'progression'},class='PRIEST',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},BuiltinConditions.all({type='CHANNELING',unit='player'},BuiltinConditions.negate(clip)),BuiltinConditions.negate({type='ATTACKABLE',unit='target'}))),
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  BuiltinConditions.spell('pull-spike',73510),
  BuiltinConditions.spell('pull-blast',8092),
  BuiltinConditions.spell('pull-touch',34914),
  BuiltinConditions.spell('pull-pain',589),
  BuiltinConditions.spell('pull-flay',15407),
  BuiltinConditions.stop('pull-stop'),
 }},
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  BuiltinConditions.spell('moving-plague',2944,{type='POINT',unit='player',operator='GREATERTHANOREQUALS',value=3}),
  BuiltinConditions.spell('moving-death',32379,execute),
  BuiltinConditions.spell('moving-insight',8092,BuiltinConditions.ownBuff(124430)),
  BuiltinConditions.spell('moving-surge',73510,BuiltinConditions.ownBuff(87160)),
  BuiltinConditions.spell('moving-halo',120517,BuiltinConditions.all(BuiltinConditions.negate({type='DISTANCE',unit='target',value=15}),{type='DISTANCE',unit='target',value=30})),
  BuiltinConditions.spell('moving-cascade',121135,BuiltinConditions.negate({type='DISTANCE',unit='target',value=10})),
  BuiltinConditions.spell('moving-divine-star',110744,{type='DISTANCE',unit='target',value=24}),
  BuiltinConditions.spell('moving-pain',589),
  BuiltinConditions.stop('moving-stop'),
 }},
 {id='aoe',type='branch',conditions=enemies('GREATERTHANOREQUALS',5),onFalse={},onTrue={
  BuiltinConditions.spell('aoe-halo',120517),
  BuiltinConditions.spell('aoe-cascade',121135),
  BuiltinConditions.spell('aoe-divine-star',110744),
  BuiltinConditions.spell('aoe-touch',34914,BuiltinConditions.all(BuiltinConditions.negate(dot(34914)),lives(10))),
  BuiltinConditions.spell('aoe-pain',589,BuiltinConditions.all(BuiltinConditions.negate(dot(589)),lives(10))),
  BuiltinConditions.spell('aoe-sear',48045),
  BuiltinConditions.stop('aoe-stop',{type='SPELL_KNOWN',spell=48045}),
 }},
}}))
-- Shadow reminders: Shadowform, Silence, Shadowfiend or Mindbender and Power Infusion on long fights (damage
-- cooldowns for Shadow), Vampiric Embrace, Desperate Prayer and Dispersion when low (RM policy), Psychic Scream
-- (off: levelling safety when three enemies are on you).
assert(addon:RegisterDefaultBlock({
 id='mop.priest.shadow-cooldowns',revision=2,families={'progression'},class='PRIEST',steps={
 BuiltinConditions.spell('shadowform',15473,BuiltinConditions.negate({type='FORM',form=15473})),
 BuiltinConditions.spell('silence',15487,BuiltinConditions.any({type='CAST_INTERRUPTABLE',unit='target'},{type='CHANNEL_INTERRUPTABLE',unit='target'})),
 BuiltinConditions.spell('shadowfiend',34433,BuiltinConditions.all(BuiltinConditions.combat(),worth)),
 BuiltinConditions.spell('mindbender',123040,BuiltinConditions.all(BuiltinConditions.combat(),worth)),
 BuiltinConditions.spell('power-infusion',10060,BuiltinConditions.all(BuiltinConditions.combat(),worth)),
 BuiltinConditions.spell('vampiric-embrace',15286,BuiltinConditions.all(BuiltinConditions.combat(),health('player','LESSTHANOREQUALS',.4))),
 BuiltinConditions.spell('desperate-prayer',19236,health('player','LESSTHAN',.35)),
 BuiltinConditions.spell('dispersion',47585,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(mana('LESSTHAN',.15),health('player','LESSTHAN',.25)))),
 {id='psychic-scream',type='spell',action=8122,ranked=false,disabled=true,conditions=BuiltinConditions.all(health('player','LESSTHAN',.5),
  {type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=3})},
}}))
