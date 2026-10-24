-- Shared Classic Era and Season of Discovery Priest blocks (Built In composition; authoring-time only).
-- Consumers: rm.era.priest.dps, rm.era.priest.dps.warcrafttavern, rm.era.priest.dps.wowsims,
-- rm.era.priest.healer, rm.sod.priest.dps, rm.sod.priest.dps.wowhead, rm.sod.priest.healer and
-- rm.sod.priest.healer.warcrafttavern. A content change needs a block revision bump, every
-- consumer's pin and revision bumped, and both recorded in tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
-- Season of Discovery runes: engraved, by the spell the rune teaches (passive runes too).
local function rune(id)return{type='RUNE_ENGRAVED',spell=id}end
local function missing(id)return negate({type='BUFF',unit='player',spell=id,anyrank=true})end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function fading(id)return any(negate(own(id)),{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5})end
local function combat()return{type='COMBAT',unit='player'}end
local function pct(kind,unit,op,v)return{type=kind,unit=unit,operator=op,value=v}end
local function lives(seconds)return any(pct('HEALTHPCT','target','GREATERTHANOREQUALS',.5),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=seconds})end
local function hurt(health,count)return{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',healthoperator='LESSTHAN',health=health,operator='GREATERTHANOREQUALS',value=count,distance=30,samegroup=true}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
local function block(id,steps,revision)assert(addon:RegisterDefaultBlock({id=id,revision=revision or 1,families={'era'},class='PRIEST',steps=steps}))end
local solo=negate({type='GROUP'})
local raid={type='INSTANCE',value='raid'}
local shadowform=known(15473)

-- Vanilla and Season of Discovery.
block('era.priest.boundaries',{
 stop('cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'})),
},2)
-- Damage needs a living hostile target that is not someone else's fight.
local enemyGone=negate(all({type='ATTACKABLE',unit='target'},any(combat(),negate({type='COMBAT',unit='target'}))))
block('era.priest.enemy-target',{
 stop('target',enemyGone),
})
-- Damage premades: a cast or channel, or no such target, ends advice (one Stop).
block('era.priest.dps-boundaries',{
 stop('cast',any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},enemyGone)),
})
block('era.priest.shadowform',{
 spell('shadowform',15473,negate({type='BUFF',unit='player',spell=15473})),
})
-- Solo, a low target or a low mana pool is wanded (Spirit Tap wants the killing blow). No
-- trailing Stop: without a wand the priority carries on.
block('era.priest.wand-finish',{
 {id='wand-finish',type='branch',conditions=all(solo,any(pct('HEALTHPCT','target','LESSTHAN',.3),pct('MANAPCT','player','LESSTHAN',.25))),onFalse={},onTrue={
  stop('wand-finish-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),spell('wand-finish-shoot',5019)}},
})
-- Out of everything else: the wand, never toggled off; priests never melee.
block('era.priest.wand-fallback',{
 stop('wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),
 spell('shoot',5019),
 stop('exhausted'),
})
-- Independent reminders for every Priest premade. Fortitude goes on your current target, so it
-- only lights out of combat.
block('era.priest.upkeep',{
 spell('inner-fire',588,missing(588)),
 spell('fortitude',1243,all(negate(combat()),missing(1243),missing(21562))),
 spell('touch-of-weakness',2652,all(negate(combat()),missing(2652))),
 spell('shadowguard',18137,all(negate(combat()),missing(18137))),
 spell('desperate-prayer',13908,pct('HEALTHPCT','player','LESSTHAN',.3)),
})
-- Damage reminders: Inner Focus with a ready Mind Blast, solo Psychic Scream when two enemies
-- reach you at half health, Fade when your target turns on you in a group.
block('era.priest.dps-upkeep',{
 spell('inner-focus',14751,all(combat(),{type='SPELL_COOLDOWN',spell=8092,operator='LESSTHANOREQUALS',value=1.5})),
 spell('scream',8122,all(solo,pct('HEALTHPCT','player','LESSTHAN',.5),{type='DISTANCE_COUNT',enemy=true,distance=8,operator='GREATERTHANOREQUALS',value=2})),
 spell('fade',586,all({type='GROUP'},combat(),{type='THREAT',unit='target',threat=2})),
})
-- Shield yourself before a solo pull.
block('era.priest.pull-shield',{
 spell('pull-shield',17,all(solo,negate({type='DEBUFF',unit='player',spell=6788}))),
})
block('era.priest.dispels',{
 spell('dispel-magic',527,{type='DISPELLABLE',unit='target',debufftype='Magic'}),
 {id='disease',type='branch',conditions={type='DISPELLABLE',unit='target',debufftype='Disease'},onFalse={},onTrue={
  spell('abolish-disease',552,negate({type='BUFF',unit='target',spell=552})),
  spell('cure-disease',528,negate(known(552)))}},
})
-- Healing on your friendly target: the biggest learned heal below half health, Renew while
-- moving or on a mildly hurt target.
block('era.priest.big-heal',{
 {id='big-heal',type='branch',conditions=pct('HEALTHPCT','target','LESSTHAN',.5),onFalse={},onTrue={
  {id='greater-known',type='branch',conditions=known(2060),onTrue={spell('greater-heal',2060)},onFalse={
   {id='heal-known',type='branch',conditions=known(2054),onTrue={spell('heal',2054)},onFalse={spell('lesser-heal',2050)}}}}}},
})
block('era.priest.renew',{
 spell('renew',139,all(negate({type='BUFF',unit='target',spell=139,anyrank=true,ownbuff=true}),any({type='MOVING'},pct('HEALTHPCT','target','LESSTHAN',.9)))),
})
-- Out of combat on a friend: Fortitude if neither Fortitude is on them.
block('era.priest.friend-fortitude',{
 spell('friend-fortitude',1243,all(negate({type='BUFF',unit='target',spell=1243,anyrank=true}),negate({type='BUFF',unit='target',spell=21562,anyrank=true}))),
})
block('era.priest.divine-spirit',{
 spell('divine-spirit',14752,all(negate(combat()),missing(14752),missing(27681))),
 spell('inner-focus-heal',14751,combat()),
 {id='power-infusion',type='spell',action=10060,ranked=false,disabled=true,conditions=combat()},
})

-- Vanilla only.
-- Pull: shield (solo), Holy Fire for builds without Shadowform, Mind Blast, Smite.
block('era.priest.pull',{
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  {id='pull-shield',type='block',block='era.priest.pull-shield',prefix='pull-'},
  spell('pull-holy-fire',14914,negate(shadowform)),
  spell('pull-blast',8092),
  spell('pull-smite',585),
  stop('pull-stop')}},
},2)
-- Moving: instants only. Devouring Plague stays out of raids (debuff slots).
block('era.priest.moving',{
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('moving-pain',589,negate(own(589))),
  spell('moving-plague',2944,all(negate(own(2944)),negate(raid))),
  stop('moving-stop')}},
})
-- Shadow Word: Pain once per target that will live through it.
block('era.priest.pain',{
 spell('pain',589,all(negate(own(589)),lives(10))),
})
-- Filler: Mind Flay once learned (rank-1 Mind Flay and Pain when a raid drains you, off by
-- default); without it Holy Nova on three enemies at hand, then Smite.
block('era.priest.filler',{
 {id='flay-known',type='branch',conditions=known(15407),onTrue={
  {id='raid-pain-r1',type='spell',action=589,ranked=true,disabled=true,conditions=all(raid,pct('MANAPCT','player','LESSTHAN',.1),negate(own(589)))},
  {id='raid-flay-r1',type='spell',action=15407,ranked=true,disabled=true,conditions=all(raid,pct('MANAPCT','player','LESSTHAN',.1))},
  spell('flay',15407)},onFalse={
  spell('holy-nova',15237,{type='DISTANCE_COUNT',enemy=true,distance=10,operator='GREATERTHANOREQUALS',value=3}),
  spell('smite',585),
  stop('smite-stop')}},
})

-- Season of Discovery only.
block('sod.priest.upkeep',{
 spell('homunculi',402799,all(combat(),any({type='CLASSIFICATION',unit='target',value='worldboss'},{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=20}))),
 spell('shadowfiend',401977,all(combat(),{type='ATTACKABLE',unit='target'},any(pct('MANAPCT','player','LESSTHAN',.7),{type='CLASSIFICATION',unit='target',value='worldboss'}))),
 spell('eye-of-the-void',402789,all(combat(),{type='CLASSIFICATION',unit='target',value='worldboss'})),
 spell('dispersion',425294,all(combat(),pct('MANAPCT','player','LESSTHAN',.15))),
 spell('embrace',15286,all(combat(),negate(rune(402668)),negate({type='DEBUFF',unit='target',spell=15286,owndebuff=true}),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=60})),
},2)
-- Pull: shield (solo), pre-cast Vampiric Touch, Mind Blast; Penance and Holy Fire before Shadowform.
block('sod.priest.pull',{
 {id='pull',type='branch',conditions=combat(),onTrue={},onFalse={
  {id='pull-shield',type='block',block='era.priest.pull-shield',prefix='pull-'},
  spell('pull-touch',402668),
  spell('pull-blast',8092),
  spell('pull-penance',402174,negate(shadowform)),
  spell('pull-holy-fire',14914,negate(shadowform)),
  spell('pull-smite',585),
  stop('pull-stop')}},
},2)
-- Four or more engaged enemies: Void Zone, then Mind Sear; single-target play follows.
block('sod.priest.aoe',{
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=4},onFalse={},onTrue={
  spell('aoe-void-zone',431681),
  spell('aoe-mind-sear',413259)}},
})
block('sod.priest.moving',{
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('moving-void-plague',425204,negate(own(425204))),
  spell('moving-pain',589,negate(own(589))),
  spell('moving-death',401955,pct('HEALTHPCT','player','GREATERTHANOREQUALS',.5)),
  stop('moving-stop')}},
})
-- DoTs: applied when missing; refreshed under 1.5 s only without the Pain and Suffering rune (passive,
-- 413251), whose Mind Blast, Mind Flay and Mind Spike keep them rolling.
local painAndSuffering=rune(413251)
local function due(id)return any(negate(own(id)),all(negate(painAndSuffering),{type='DEBUFF_REMAIN',unit='target',spell=id,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5}))end
block('sod.priest.dots',{
 spell('void-plague',425204,due(425204)),
 spell('pain',589,all(due(589),lives(10))),
 spell('touch',402668,all(due(402668),lives(9))),
 spell('plague',2944,all(negate(own(2944)),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=12})),
},2)
-- After Mind Blast: Mind Flay on Melting Faces, Shadow Word: Death while healthy, Penance before Shadowform.
block('sod.priest.procs',{
 spell('melting-flay',15407,{type='BUFF',unit='player',spell=456549}),
 spell('death',401955,pct('HEALTHPCT','player','GREATERTHANOREQUALS',.5)),
 spell('penance',402174,negate(shadowform)),
})
-- Filler: Mind Spike, else Mind Flay, else Smite.
block('sod.priest.filler',{
 spell('mind-spike',431655),
 spell('flay',15407),
 spell('smite',585),
})
-- Healer pointed at an enemy: Pain, Void Plague, Penance, Holy Fire, Smite.
block('sod.priest.healer-damage',{
 {id='enemy-target',type='block',block='era.priest.enemy-target',prefix='enemy-'},
 spell('enemy-pain',589,all(negate(own(589)),{type='TT_HEALTH',unit='target',health=0,operator='GREATERTHANOREQUALS',value=12})),
 spell('enemy-void-plague',425204,negate(own(425204))),
 spell('enemy-penance',402174),
 spell('enemy-holy-fire',14914,negate(own(14914))),
 spell('enemy-smite',585),
 stop('enemy-stop'),
})
-- Healer cooldowns: Shadowfiend, Pain Suppression, Power Word: Barrier, Spirit of the Redeemer.
block('sod.priest.healer-upkeep',{
 spell('shadowfiend-heal',401977,all(combat(),pct('MANAPCT','player','LESSTHAN',.6))),
 spell('pain-suppression',402004,all(combat(),{type='FRIENDLY',unit='target'},pct('HEALTHPCT','target','LESSTHAN',.3))),
 spell('barrier',425207,all(combat(),hurt(.6,3))),
 spell('redeemer',425284,all(combat(),any(pct('MANAPCT','player','LESSTHAN',.1),hurt(.5,3)))),
})
