-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared TBC Priest blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.priest.dps.icyveins, rm.tbc.priest.dps.wowhead,
-- rm.tbc.priest.healer.wowhead and rm.tbc.priest.healer.icyveins. A content change needs a
-- block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function missing(id)return BuiltinConditions.negate({type='BUFF',unit='player',spell=id,anyrank=true})end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function pct(kind,unit,op,v)return{type=kind,unit=unit,operator=op,value=v}end
-- A cast stops the list; a channel too, unless it is Mind Flay (any rank) past its first tick (a third
-- of the channel: ticks are evenly spaced) and Mind Blast, or Shadow Word: Death while you can take the
-- backlash, is ready to clip it (Icy Veins, Wowhead). Other channels are never cut.
local clip=BuiltinConditions.all({type='CHANNELING_SPELL',unit='player',spell=15407},{type='CHANNELING_PROGRESS',unit='player',operator='GREATERTHANOREQUALS',value=.34},
 BuiltinConditions.any({type='SPELL_AVAIL',spell=8092},BuiltinConditions.all(BuiltinConditions.known(32379),pct('HEALTHPCT','player','GREATERTHAN',.5),{type='SPELL_AVAIL',spell=32379})))
assert(addon:RegisterDefaultBlock({id='tbc.priest.boundaries',revision=4,families={'tbc'},class='PRIEST',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},BuiltinConditions.all({type='CHANNELING',unit='player'},BuiltinConditions.negate(clip)))),
}}))
-- Damage needs a living hostile target that is not someone else's fight.
local enemyGone=BuiltinConditions.negate(BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.any(BuiltinConditions.combat(),BuiltinConditions.negate({type='COMBAT',unit='target'}))))
assert(addon:RegisterDefaultBlock({id='tbc.priest.enemy-target',revision=2,families={'tbc'},class='PRIEST',steps={
 BuiltinConditions.stop('target',enemyGone),
}}))
-- Damage premades: the boundaries above, or no such target, end advice (one Stop).
assert(addon:RegisterDefaultBlock({id='tbc.priest.dps-boundaries',revision=2,families={'tbc'},class='PRIEST',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},BuiltinConditions.all({type='CHANNELING',unit='player'},BuiltinConditions.negate(clip)),enemyGone)),
}}))
assert(addon:RegisterDefaultBlock({id='tbc.priest.shadowform',revision=1,families={'tbc'},class='PRIEST',steps={
 BuiltinConditions.spell('shadowform',15473,BuiltinConditions.negate({type='BUFF',unit='player',spell=15473})),
}}))
-- Moving: instants only, then stop. Shadow Word: Death only while you can take the backlash.
assert(addon:RegisterDefaultBlock({id='tbc.priest.moving',revision=2,families={'tbc'},class='PRIEST',steps={
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  BuiltinConditions.spell('moving-pain',589,BuiltinConditions.negate(own(589))),
  BuiltinConditions.spell('moving-death',32379,pct('HEALTHPCT','player','GREATERTHAN',.5)),
  BuiltinConditions.spell('moving-starshards',10797),
  BuiltinConditions.spell('moving-plague',2944,BuiltinConditions.negate(own(2944))),
  BuiltinConditions.stop('moving-stop')}},
}}))
-- Damage over time: Vampiric Touch refreshed about one cast before it ends, Pain only once it
-- has dropped, racial Starshards / Devouring Plague.
assert(addon:RegisterDefaultBlock({id='tbc.priest.dots',revision=1,families={'tbc'},class='PRIEST',steps={
 BuiltinConditions.spell('touch',34914,BuiltinConditions.any(BuiltinConditions.negate(own(34914)),{type='DEBUFF_REMAIN',unit='target',spell=34914,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5})),
 BuiltinConditions.spell('pain',589,BuiltinConditions.negate(own(589))),
 BuiltinConditions.spell('starshards',10797),
 BuiltinConditions.spell('plague',2944,BuiltinConditions.negate(own(2944))),
}}))
-- Filler: Mind Flay once learned; without it (early levels, Holy and Discipline questing)
-- Holy Fire, Holy Nova on three attackers, Smite. Then the wand; priests never melee.
assert(addon:RegisterDefaultBlock({id='tbc.priest.filler',revision=2,families={'tbc'},class='PRIEST',steps={
 {id='flay-known',type='branch',conditions=BuiltinConditions.known(15407),onTrue={BuiltinConditions.spell('flay',15407)},onFalse={
  BuiltinConditions.spell('holy-fire',14914,BuiltinConditions.negate(own(14914))),
  BuiltinConditions.spell('holy-nova',15237,{type='THREAT_COUNT',threat=3,operator='GREATERTHANOREQUALS',value=3}),
  BuiltinConditions.spell('smite',585)}},
 {id='wand-known',type='branch',conditions=BuiltinConditions.known(5019),onFalse={},onTrue={
  BuiltinConditions.stop('wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),BuiltinConditions.spell('shoot',5019)}},
 BuiltinConditions.stop('exhausted'),
}}))
-- Independent reminders for every Priest premade. Fortitude needs a friendly target in range
-- (yourself included) because RM casts on your current target.
assert(addon:RegisterDefaultBlock({id='tbc.priest.upkeep',revision=1,families={'tbc'},class='PRIEST',steps={
 BuiltinConditions.spell('inner-fire',588,missing(588)),
 BuiltinConditions.spell('fortitude',1243,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),missing(1243),missing(21562))),
 BuiltinConditions.spell('touch-of-weakness',2652,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),missing(2652))),
 BuiltinConditions.spell('shadowguard',18137,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),missing(18137))),
 BuiltinConditions.spell('shadowfiend',34433,BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'},pct('MANAPCT','player','LESSTHAN',.5))),
 BuiltinConditions.spell('desperate-prayer',13908,pct('HEALTHPCT','player','LESSTHAN',.3)),
}}))
-- Healing on your friendly target: dispels, group heals, then the efficient big heal.
assert(addon:RegisterDefaultBlock({id='tbc.priest.dispels',revision=1,families={'tbc'},class='PRIEST',steps={
 BuiltinConditions.spell('dispel-magic',527,{type='DISPELLABLE',unit='target',debufftype='Magic'}),
 {id='disease',type='branch',conditions={type='DISPELLABLE',unit='target',debufftype='Disease'},onFalse={},onTrue={
  BuiltinConditions.spell('abolish-disease',552,BuiltinConditions.negate({type='BUFF',unit='target',spell=552})),
  BuiltinConditions.spell('cure-disease',528,BuiltinConditions.negate(BuiltinConditions.known(552)))}},
}}))
assert(addon:RegisterDefaultBlock({id='tbc.priest.group-heal',revision=1,families={'tbc'},class='PRIEST',steps={
 BuiltinConditions.spell('circle',34861,{type='PROXIMITY_HEALTHPCT_COUNT',unit='target',healthoperator='LESSTHAN',health=.85,operator='GREATERTHANOREQUALS',value=3,distance=15}),
 BuiltinConditions.spell('prayer-of-healing',596,{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',healthoperator='LESSTHAN',health=.85,operator='GREATERTHANOREQUALS',value=3,distance=30,samegroup=true}),
}}))
assert(addon:RegisterDefaultBlock({id='tbc.priest.big-heal',revision=1,families={'tbc'},class='PRIEST',steps={
 {id='big-heal',type='branch',conditions=pct('HEALTHPCT','target','LESSTHAN',.7),onFalse={},onTrue={
  {id='greater-known',type='branch',conditions=BuiltinConditions.known(2060),onTrue={BuiltinConditions.spell('greater-heal',2060)},onFalse={
   {id='heal-known',type='branch',conditions=BuiltinConditions.known(2054),onTrue={BuiltinConditions.spell('heal',2054)},onFalse={BuiltinConditions.spell('lesser-heal',2050)}}}}}},
}}))
-- An enemy target instead of a friend: light damage (own Pain, own Holy Fire, Smite).
assert(addon:RegisterDefaultBlock({id='tbc.priest.healer-damage',revision=2,families={'tbc'},class='PRIEST',steps={
 {id='enemy',type='branch',conditions=BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.any(BuiltinConditions.combat(),BuiltinConditions.negate({type='COMBAT',unit='target'}))),onFalse={},onTrue={
  BuiltinConditions.spell('enemy-pain',589,BuiltinConditions.negate(own(589))),BuiltinConditions.spell('enemy-holy-fire',14914,BuiltinConditions.negate(own(14914))),BuiltinConditions.spell('enemy-smite',585)}},
 BuiltinConditions.stop('idle'),
}}))
