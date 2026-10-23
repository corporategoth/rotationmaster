-- Shared TBC Priest blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.priest.dps.icyveins, rm.tbc.priest.dps.wowhead,
-- rm.tbc.priest.healer.wowhead and rm.tbc.priest.healer.icyveins. A content change needs a
-- block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
local _,addon=...
local function all(...)return{type='AND',value={...}}end
local function any(...)return{type='OR',value={...}}end
local function negate(c)return{type='NOT',value=c}end
local function known(id)return{type='SPELL_KNOWN',spell=id}end
local function missing(id)return negate({type='BUFF',unit='player',spell=id,anyrank=true})end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function combat()return{type='COMBAT',unit='player'}end
local function pct(kind,unit,op,v)return{type=kind,unit=unit,operator=op,value=v}end
local function spell(id,action,conditions)return{id=id,type='spell',action=action,ranked=false,conditions=conditions or {}}end
local function stop(id,conditions)return{id=id,type='none',suppress_attack=true,conditions=conditions or {}}end
assert(addon:RegisterDefaultBlock({id='tbc.priest.boundaries',revision=1,families={'tbc'},class='PRIEST',steps={
 stop('cast',{type='CASTING',unit='player'}),
 stop('channel',{type='CHANNELING',unit='player'}),
}}))
-- Damage needs a living hostile target that is not someone else's fight.
assert(addon:RegisterDefaultBlock({id='tbc.priest.enemy-target',revision=1,families={'tbc'},class='PRIEST',steps={
 stop('target',negate(all({type='ATTACKABLE',unit='target'},any(combat(),negate({type='COMBAT',unit='target'}))))),
}}))
assert(addon:RegisterDefaultBlock({id='tbc.priest.shadowform',revision=1,families={'tbc'},class='PRIEST',steps={
 spell('shadowform',15473,negate({type='BUFF',unit='player',spell=15473})),
}}))
-- Moving: instants only, then stop. Shadow Word: Death only while you can take the backlash.
assert(addon:RegisterDefaultBlock({id='tbc.priest.moving',revision=1,families={'tbc'},class='PRIEST',steps={
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  spell('moving-pain',589,negate(own(589))),
  spell('moving-death',32379,pct('HEALTHPCT','player','GREATERTHAN',.5)),
  spell('moving-starshards',10797),
  spell('moving-plague',2944,negate(own(2944))),
  stop('moving-stop')}},
}}))
-- Damage over time: Vampiric Touch refreshed about one cast before it ends, Pain only once it
-- has dropped, racial Starshards / Devouring Plague.
assert(addon:RegisterDefaultBlock({id='tbc.priest.dots',revision=1,families={'tbc'},class='PRIEST',steps={
 spell('touch',34914,any(negate(own(34914)),{type='DEBUFF_REMAIN',unit='target',spell=34914,anyrank=true,owndebuff=true,operator='LESSTHAN',value=1.5})),
 spell('pain',589,negate(own(589))),
 spell('starshards',10797),
 spell('plague',2944,negate(own(2944))),
}}))
-- Filler: Mind Flay once learned; without it (early levels, Holy and Discipline questing)
-- Holy Fire, Holy Nova on three attackers, Smite. Then the wand; priests never melee.
assert(addon:RegisterDefaultBlock({id='tbc.priest.filler',revision=1,families={'tbc'},class='PRIEST',steps={
 {id='flay-known',type='branch',conditions=known(15407),onTrue={spell('flay',15407)},onFalse={
  spell('holy-fire',14914,negate(own(14914))),
  spell('holy-nova',15237,{type='THREAT_COUNT',threat=3,operator='GREATERTHANOREQUALS',value=3}),
  spell('smite',585)}},
 {id='wand-known',type='branch',conditions=known(5019),onFalse={},onTrue={
  stop('wand-active',{type='SPELL_AUTOREPEAT',spell=5019,ranked=true}),spell('shoot',5019)}},
 stop('exhausted'),
}}))
-- Independent reminders for every Priest premade. Fortitude needs a friendly target in range
-- (yourself included) because RM casts on your current target.
assert(addon:RegisterDefaultBlock({id='tbc.priest.upkeep',revision=1,families={'tbc'},class='PRIEST',steps={
 spell('inner-fire',588,missing(588)),
 spell('fortitude',1243,all(negate(combat()),missing(1243),missing(21562))),
 spell('touch-of-weakness',2652,all(negate(combat()),missing(2652))),
 spell('shadowguard',18137,all(negate(combat()),missing(18137))),
 spell('shadowfiend',34433,all(combat(),{type='ATTACKABLE',unit='target'},pct('MANAPCT','player','LESSTHAN',.5))),
 spell('desperate-prayer',13908,pct('HEALTHPCT','player','LESSTHAN',.3)),
}}))
-- Healing on your friendly target: dispels, group heals, then the efficient big heal.
assert(addon:RegisterDefaultBlock({id='tbc.priest.dispels',revision=1,families={'tbc'},class='PRIEST',steps={
 spell('dispel-magic',527,{type='DISPELLABLE',unit='target',debufftype='Magic'}),
 {id='disease',type='branch',conditions={type='DISPELLABLE',unit='target',debufftype='Disease'},onFalse={},onTrue={
  spell('abolish-disease',552,negate({type='BUFF',unit='target',spell=552})),
  spell('cure-disease',528,negate(known(552)))}},
}}))
assert(addon:RegisterDefaultBlock({id='tbc.priest.group-heal',revision=1,families={'tbc'},class='PRIEST',steps={
 spell('circle',34861,{type='PROXIMITY_HEALTHPCT_COUNT',unit='target',healthoperator='LESSTHAN',health=.85,operator='GREATERTHANOREQUALS',value=3,distance=15}),
 spell('prayer-of-healing',596,{type='PROXIMITY_HEALTHPCT_COUNT',unit='player',healthoperator='LESSTHAN',health=.85,operator='GREATERTHANOREQUALS',value=3,distance=30,samegroup=true}),
}}))
assert(addon:RegisterDefaultBlock({id='tbc.priest.big-heal',revision=1,families={'tbc'},class='PRIEST',steps={
 {id='big-heal',type='branch',conditions=pct('HEALTHPCT','target','LESSTHAN',.7),onFalse={},onTrue={
  {id='greater-known',type='branch',conditions=known(2060),onTrue={spell('greater-heal',2060)},onFalse={
   {id='heal-known',type='branch',conditions=known(2054),onTrue={spell('heal',2054)},onFalse={spell('lesser-heal',2050)}}}}}},
}}))
-- An enemy target instead of a friend: light damage (own Pain, own Holy Fire, Smite).
assert(addon:RegisterDefaultBlock({id='tbc.priest.healer-damage',revision=1,families={'tbc'},class='PRIEST',steps={
 {id='enemy',type='branch',conditions=all({type='ATTACKABLE',unit='target'},any(combat(),negate({type='COMBAT',unit='target'}))),onFalse={},onTrue={
  spell('enemy-pain',589,negate(own(589))),spell('enemy-holy-fire',14914,negate(own(14914))),spell('enemy-smite',585)}},
 stop('idle'),
}}))
