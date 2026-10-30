-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared Classic Era and Season of Discovery Priest blocks (Built In composition; authoring-time only).
-- Consumers: rm.era.priest.dps, rm.era.priest.dps.warcrafttavern, rm.era.priest.dps.simulator,
-- rm.era.priest.healer, rm.sod.priest.dps, rm.sod.priest.dps.wowhead, rm.sod.priest.healer and
-- rm.sod.priest.healer.warcrafttavern. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
-- Season of Discovery runes: engraved, by the spell the rune teaches (passive runes too).
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function missing(id)return BuiltinConditions.negate({type='BUFF',unit='player',spell=id,anyrank=true})end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function fading(id)return BuiltinConditions.any(BuiltinConditions.negate(own(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5})end
local function pct(kind,unit,op,v)return{type=kind,unit=unit,operator=op,value=v}end
local function lives(seconds)return BuiltinConditions.any(pct('HEALTHPCT','target','GREATERTHANOREQUALS',.5),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=seconds})end
local function hurt(health,count)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',healthoperator='LESSTHAN',health=health,operator='GREATERTHANOREQUALS',value=count,distance=30,samegroup=true}end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'era'},class='PRIEST',steps=steps}))end
local solo=BuiltinConditions.negate({type='GROUP'})
local raid={type='INSTANCE',value='raid'}
local shadowform=BuiltinConditions.known(15473)

-- Vanilla and Season of Discovery.
block('era.priest.boundaries',{
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
},3)
-- Damage needs a living hostile target that is not someone else's fight.
local enemyGone=BuiltinConditions.negate(BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.any(BuiltinConditions.combat(),BuiltinConditions.negate({type='COMBAT',unit='target'}))))
block('era.priest.enemy-target',{
 BuiltinConditions.stop('target',enemyGone),
},2)
-- Damage premades: a cast or channel, or no such target, ends advice (one Stop).
block('era.priest.dps-boundaries',{
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},enemyGone)),
},2)
block('era.priest.shadowform',{
 BuiltinConditions.spell('shadowform',15473,BuiltinConditions.negate({type='BUFF',unit='player',spell=15473})),
})
-- Solo, a low target or a low mana pool is wanded (Spirit Tap wants the killing blow). No
-- trailing Stop: without a wand the priority carries on.
block('era.priest.wand-finish',{
 {id='wand-finish',type='branch',conditions=BuiltinConditions.all(solo,BuiltinConditions.any(pct('HEALTHPCT','target','LESSTHAN',.3),pct('MANAPCT','player','LESSTHAN',.25))),onFalse={},onTrue={
  BuiltinConditions.stop('wand-finish-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),BuiltinConditions.spell('wand-finish-shoot',5019)}},
},2)
-- Out of everything else: the wand, never toggled off; priests never melee.
block('era.priest.wand-fallback',{
 BuiltinConditions.stop('wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),
 BuiltinConditions.spell('shoot',5019),
 BuiltinConditions.stop('exhausted'),
},2)
-- Independent reminders for every Priest premade. Fortitude goes on your current target, so it
-- only lights out of combat.
block('era.priest.upkeep',{
 BuiltinConditions.spell('inner-fire',588,missing(588)),
 BuiltinConditions.spell('fortitude',1243,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),missing(1243),missing(21562))),
 BuiltinConditions.spell('touch-of-weakness',2652,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),missing(2652))),
 BuiltinConditions.spell('shadowguard',18137,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),missing(18137))),
 BuiltinConditions.spell('desperate-prayer',13908,pct('HEALTHPCT','player','LESSTHAN',.3)),
})
-- Damage reminders: Inner Focus with a ready Mind Blast, solo Psychic Scream when two enemies
-- reach you at half health, Fade when your target turns on you in a group.
block('era.priest.dps-upkeep',{
 BuiltinConditions.spell('inner-focus',14751,BuiltinConditions.all(BuiltinConditions.combat(),{type='SPELL_COOLDOWN',spell=8092,operator='LESSTHANOREQUALS',value=1.5})),
 BuiltinConditions.spell('scream',8122,BuiltinConditions.all(solo,pct('HEALTHPCT','player','LESSTHAN',.5),{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2})),
 BuiltinConditions.spell('fade',586,BuiltinConditions.all({type='GROUP'},BuiltinConditions.combat(),{type='THREAT',unit='target',threat=2})),
})
-- Shield yourself before a solo pull.
block('era.priest.pull-shield',{
 BuiltinConditions.spell('pull-shield',17,BuiltinConditions.all(solo,BuiltinConditions.negate({type='DEBUFF',unit='player',spell=6788}))),
})
block('era.priest.dispels',{
 BuiltinConditions.spell('dispel-magic',527,{type='DISPELLABLE',unit='target',debufftype='Magic'}),
 {id='disease',type='branch',conditions={type='DISPELLABLE',unit='target',debufftype='Disease'},onFalse={},onTrue={
  BuiltinConditions.spell('abolish-disease',552,BuiltinConditions.negate({type='BUFF',unit='target',spell=552})),
  BuiltinConditions.spell('cure-disease',528,BuiltinConditions.negate(BuiltinConditions.known(552)))}},
})
-- Healing on your friendly target: the biggest learned heal below half health, Renew while
-- moving or on a mildly hurt target.
block('era.priest.big-heal',{
 {id='big-heal',type='branch',conditions=pct('HEALTHPCT','target','LESSTHAN',.5),onFalse={},onTrue={
  {id='greater-known',type='branch',conditions=BuiltinConditions.known(2060),onTrue={BuiltinConditions.spell('greater-heal',2060)},onFalse={
   {id='heal-known',type='branch',conditions=BuiltinConditions.known(2054),onTrue={BuiltinConditions.spell('heal',2054)},onFalse={BuiltinConditions.spell('lesser-heal',2050)}}}}}},
})
block('era.priest.renew',{
 BuiltinConditions.spell('renew',139,BuiltinConditions.all(BuiltinConditions.negate({type='BUFF',unit='target',spell=139,anyrank=true,ownbuff=true}),BuiltinConditions.any({type='MOVING'},pct('HEALTHPCT','target','LESSTHAN',.9)))),
})
-- Out of combat on a friend: Fortitude if neither Fortitude is on them.
block('era.priest.friend-fortitude',{
 BuiltinConditions.spell('friend-fortitude',1243,BuiltinConditions.all(BuiltinConditions.negate({type='BUFF',unit='target',spell=1243,anyrank=true}),BuiltinConditions.negate({type='BUFF',unit='target',spell=21562,anyrank=true}))),
})
block('era.priest.divine-spirit',{
 BuiltinConditions.spell('divine-spirit',14752,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),missing(14752),missing(27681))),
 BuiltinConditions.spell('inner-focus-heal',14751,BuiltinConditions.combat()),
 {id='power-infusion',type='spell',action=10060,ranked=false,disabled=true,conditions=BuiltinConditions.combat()},
})

-- Vanilla only.
-- Pull: shield (solo), Holy Fire for builds without Shadowform, Mind Blast, Smite.
block('era.priest.pull',{
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  {id='pull-shield',type='block',block='era.priest.pull-shield',prefix='pull-'},
  BuiltinConditions.spell('pull-holy-fire',14914,BuiltinConditions.negate(shadowform)),
  BuiltinConditions.spell('pull-blast',8092),
  BuiltinConditions.spell('pull-smite',585),
  BuiltinConditions.stop('pull-stop')}},
},3)
-- Moving: instants only. Devouring Plague stays out of raids (debuff slots).
block('era.priest.moving',{
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  BuiltinConditions.spell('moving-pain',589,BuiltinConditions.negate(own(589))),
  BuiltinConditions.spell('moving-plague',2944,BuiltinConditions.all(BuiltinConditions.negate(own(2944)),BuiltinConditions.negate(raid))),
  BuiltinConditions.stop('moving-stop')}},
},2)
-- Shadow Word: Pain once per target that will live through it.
block('era.priest.pain',{
 BuiltinConditions.spell('pain',589,BuiltinConditions.all(BuiltinConditions.negate(own(589)),lives(10))),
})
-- Filler: Mind Flay once learned (rank-1 Mind Flay and Pain when a raid drains you, off by
-- default); without it Holy Nova on three enemies at hand, then Smite.
block('era.priest.filler',{
 {id='flay-known',type='branch',conditions=BuiltinConditions.known(15407),onTrue={
  {id='raid-pain-r1',type='spell',action=589,ranked=true,disabled=true,conditions=BuiltinConditions.all(raid,pct('MANAPCT','player','LESSTHAN',.1),BuiltinConditions.negate(own(589)))},
  {id='raid-flay-r1',type='spell',action=15407,ranked=true,disabled=true,conditions=BuiltinConditions.all(raid,pct('MANAPCT','player','LESSTHAN',.1))},
  BuiltinConditions.spell('flay',15407)},onFalse={
  BuiltinConditions.spell('holy-nova',15237,{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=3}),
  BuiltinConditions.spell('smite',585),
  BuiltinConditions.stop('smite-stop')}},
},2)

-- Season of Discovery only.
block('sod.priest.upkeep',{
 BuiltinConditions.spell('homunculi',402799,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20}))),
 BuiltinConditions.spell('shadowfiend',401977,BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'},BuiltinConditions.any(pct('MANAPCT','player','LESSTHAN',.7),{type='CLASSIFICATION',unit='target',value='worldboss'}))),
 BuiltinConditions.spell('eye-of-the-void',402789,BuiltinConditions.all(BuiltinConditions.combat(),{type='CLASSIFICATION',unit='target',value='worldboss'})),
 BuiltinConditions.spell('dispersion',425294,BuiltinConditions.all(BuiltinConditions.combat(),pct('MANAPCT','player','LESSTHAN',.15))),
 BuiltinConditions.spell('embrace',15286,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate(rune(402668)),BuiltinConditions.negate({type='DEBUFF',unit='target',spell=15286,owndebuff=true}),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=60})),
},2)
-- Pull: shield (solo), pre-cast Vampiric Touch, Mind Blast; Penance and Holy Fire before Shadowform.
block('sod.priest.pull',{
 {id='pull',type='branch',conditions=BuiltinConditions.combat(),onTrue={},onFalse={
  {id='pull-shield',type='block',block='era.priest.pull-shield',prefix='pull-'},
  BuiltinConditions.spell('pull-touch',402668),
  BuiltinConditions.spell('pull-blast',8092),
  BuiltinConditions.spell('pull-penance',402174,BuiltinConditions.negate(shadowform)),
  BuiltinConditions.spell('pull-holy-fire',14914,BuiltinConditions.negate(shadowform)),
  BuiltinConditions.spell('pull-smite',585),
  BuiltinConditions.stop('pull-stop')}},
},3)
-- Four or more engaged enemies: Void Zone, then Mind Sear; single-target play follows.
block('sod.priest.aoe',{
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},onFalse={},onTrue={
  BuiltinConditions.spell('aoe-void-zone',431681),
  BuiltinConditions.spell('aoe-mind-sear',413259)}},
})
block('sod.priest.moving',{
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  BuiltinConditions.spell('moving-void-plague',425204,BuiltinConditions.negate(own(425204))),
  BuiltinConditions.spell('moving-pain',589,BuiltinConditions.negate(own(589))),
  BuiltinConditions.spell('moving-death',401955,pct('HEALTHPCT','player','GREATERTHANOREQUALS',.5)),
  BuiltinConditions.stop('moving-stop')}},
},2)
-- DoTs: applied when missing; refreshed under 1.5 s only without the Pain and Suffering rune (passive,
-- 413251), whose Mind Blast, Mind Flay and Mind Spike keep them rolling.
local painAndSuffering=rune(413251)
local function due(id)return BuiltinConditions.any(BuiltinConditions.negate(own(id)),BuiltinConditions.all(BuiltinConditions.negate(painAndSuffering),{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5}))end
block('sod.priest.dots',{
 BuiltinConditions.spell('void-plague',425204,due(425204)),
 BuiltinConditions.spell('pain',589,BuiltinConditions.all(due(589),lives(10))),
 BuiltinConditions.spell('touch',402668,BuiltinConditions.all(due(402668),lives(9))),
 BuiltinConditions.spell('plague',2944,BuiltinConditions.all(BuiltinConditions.negate(own(2944)),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=12})),
},2)
-- After Mind Blast: Mind Flay on Melting Faces, Shadow Word: Death while healthy, Penance before Shadowform.
block('sod.priest.procs',{
 BuiltinConditions.spell('melting-flay',15407,{type='BUFF',unit='player',spell=456549}),
 BuiltinConditions.spell('death',401955,pct('HEALTHPCT','player','GREATERTHANOREQUALS',.5)),
 BuiltinConditions.spell('penance',402174,BuiltinConditions.negate(shadowform)),
})
-- Filler: Mind Spike, else Mind Flay, else Smite.
block('sod.priest.filler',{
 BuiltinConditions.spell('mind-spike',431655),
 BuiltinConditions.spell('flay',15407),
 BuiltinConditions.spell('smite',585),
})
-- Healer pointed at an enemy: Pain, Void Plague, Penance, Holy Fire, Smite.
block('sod.priest.healer-damage',{
 {id='enemy-target',type='block',block='era.priest.enemy-target',prefix='enemy-'},
 BuiltinConditions.spell('enemy-pain',589,BuiltinConditions.all(BuiltinConditions.negate(own(589)),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=12})),
 BuiltinConditions.spell('enemy-void-plague',425204,BuiltinConditions.negate(own(425204))),
 BuiltinConditions.spell('enemy-penance',402174),
 BuiltinConditions.spell('enemy-holy-fire',14914,BuiltinConditions.negate(own(14914))),
 BuiltinConditions.spell('enemy-smite',585),
 BuiltinConditions.stop('enemy-stop'),
},2)
-- Healer cooldowns: Shadowfiend, Pain Suppression, Power Word: Barrier, Spirit of the Redeemer.
block('sod.priest.healer-upkeep',{
 BuiltinConditions.spell('shadowfiend-heal',401977,BuiltinConditions.all(BuiltinConditions.combat(),pct('MANAPCT','player','LESSTHAN',.6))),
 BuiltinConditions.spell('pain-suppression',402004,BuiltinConditions.all(BuiltinConditions.combat(),{type='FRIENDLY',unit='target'},pct('HEALTHPCT','target','LESSTHAN',.3))),
 BuiltinConditions.spell('barrier',425207,BuiltinConditions.all(BuiltinConditions.combat(),hurt(.6,3))),
 BuiltinConditions.spell('redeemer',425284,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.any(pct('MANAPCT','player','LESSTHAN',.1),hurt(.5,3)))),
})
