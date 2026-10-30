-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared TBC Warlock blocks (Built In composition; authoring-time only).
-- Consumers: rm.tbc.warlock.dps.icyveins and rm.tbc.warlock.dps.wowhead. A content change
-- needs a block revision bump, every consumer's pin and revision bumped, and both recorded
-- in tests/fixtures/builtin_composition_ledger.lua.
-- Talent positions (tier, then column) follow the simulator TBC layout cited by the consumers:
-- Affliction 2 Improved Corruption, 4 Improved Drain Soul; Destruction 16 Emberstorm.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id,anyrank)return{type='BUFF',unit='player',spell=id,anyrank=anyrank}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function group()return{type='GROUP'}end
local function health(op,v)return{type='HEALTHPCT',unit='player',operator=op,value=v}end
local function talent(tree,index,value)return{type='TALENT',layout='tree',tree=tree,talent=index,operator='GREATERTHANOREQUALS',value=value}end
local function shards(op,v)return{type='CARRYING',item={6265},operator=op,value=v}end
local function block(id,name,prefix)return{id=id,type='block',block=name,prefix=prefix}end
-- Fire build: Burning Wish (sacrificed Imp), or Emberstorm without Touch of Shadow.
local fire=BuiltinConditions.any(buff(18789),BuiltinConditions.all(talent(3,16,1),BuiltinConditions.negate(buff(18791))))
local curses={980,603,1490,704,1714,702}
local function ownCurse()local list={};for i,id in ipairs(curses)do list[i]=own(id)end;return{type='OR',value=list}end
assert(addon:RegisterDefaultBlock({id='tbc.warlock.boundaries',revision=3,families={'tbc'},class='WARLOCK',steps={
 -- Drain Life, Drain Soul, Hellfire, Rain of Fire and Health Funnel run to the end.
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate(BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.any(BuiltinConditions.combat(),BuiltinConditions.negate({type='COMBAT',unit='target'})))))),
}}))
-- Instant procs expire, so they come first: Nightfall's Shadow Trance and Backlash.
assert(addon:RegisterDefaultBlock({id='tbc.warlock.procs',revision=1,families={'tbc'},class='WARLOCK',steps={
 BuiltinConditions.spell('shadow-trance',686,buff(17941)),
 BuiltinConditions.spell('backlash-incinerate',29722,BuiltinConditions.all(buff(34936),fire)),
 BuiltinConditions.spell('backlash-bolt',686,buff(34936)),
}}))
-- One curse per Warlock per target. Group: Elements unless someone has it, Doom on a long
-- fight, else Agony. Solo: Doom on a long elite fight, else Agony. Others stay manual.
local longFight={type='TT_HEALTH',unit='target',health=0,operator='GREATERTHAN',value=60}
assert(addon:RegisterDefaultBlock({id='tbc.warlock.curse',revision=2,families={'tbc'},class='WARLOCK',steps={
 {id='curse-needed',type='branch',conditions=ownCurse(),onTrue={},onFalse={
  {id='curse-group',type='branch',conditions=group(),
   onTrue={BuiltinConditions.spell('elements',1490,BuiltinConditions.negate({type='DEBUFF',unit='target',spell=1490,anyrank=true})),BuiltinConditions.spell('doom-group',603,longFight),BuiltinConditions.spell('agony-group',980)},
   onFalse={BuiltinConditions.spell('doom',603,BuiltinConditions.all(BuiltinConditions.any({type='CLASSIFICATION',unit='target',value='elite'},{type='CLASSIFICATION',unit='target',value='rareelite'},
    {type='CLASSIFICATION',unit='target',value='worldboss'}),longFight)),BuiltinConditions.spell('agony',980)}},
 }},
}}))
-- Moving: instants only, then stop. Corruption counts only with five points of Improved Corruption.
assert(addon:RegisterDefaultBlock({id='tbc.warlock.moving',revision=2,families={'tbc'},class='WARLOCK',steps={
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  block('moving-curse','tbc.warlock.curse','moving-'),
  BuiltinConditions.spell('moving-corruption',172,BuiltinConditions.all(talent(1,2,5),BuiltinConditions.negate(own(172)))),
  BuiltinConditions.spell('moving-siphon',18265,BuiltinConditions.negate(own(18265))),
  BuiltinConditions.spell('moving-conflagrate',17962,own(348)),
  BuiltinConditions.spell('moving-shadowburn',17877,shards('GREATERTHANOREQUALS',2)),
  BuiltinConditions.spell('moving-tap',1454,BuiltinConditions.all({type='MANAPCT',unit='player',operator='LESSTHAN',value=.9},health('GREATERTHAN',.5))),
  BuiltinConditions.stop('moving-stop')}},
}}))
-- Three or more engaged enemies: Seed (70), Hellfire when they are on you, Shadowfury; then
-- the single-target priority continues so the main target keeps its DoTs.
assert(addon:RegisterDefaultBlock({id='tbc.warlock.aoe',revision=1,families={'tbc'},class='WARLOCK',steps={
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('seed',27243,BuiltinConditions.negate(own(27243))),
  BuiltinConditions.spell('hellfire',1949,BuiltinConditions.all({type='THREAT_COUNT',threat=3,operator='GREATERTHANOREQUALS',value=3},health('GREATERTHAN',.5))),
  BuiltinConditions.spell('shadowfury',30283)}},
}}))
-- A solo target about to die gets no new DoTs: Drain Soul for a shard (or Improved Drain
-- Soul mana), else an instant finisher.
assert(addon:RegisterDefaultBlock({id='tbc.warlock.finishers',revision=1,families={'tbc'},class='WARLOCK',steps={
 BuiltinConditions.spell('drain-soul',1120,BuiltinConditions.any(shards('LESSTHAN',5),talent(1,4,1))),
 BuiltinConditions.spell('shadowburn',17877),
 BuiltinConditions.spell('conflagrate',17962,own(348)),
}}))
-- Filler: Incinerate for a Fire build with Immolate up, else Shadow Bolt; Life Tap when nothing
-- else can be cast. Casters never melee.
assert(addon:RegisterDefaultBlock({id='tbc.warlock.filler',revision=2,families={'tbc'},class='WARLOCK',steps={
 BuiltinConditions.spell('incinerate',29722,BuiltinConditions.all(fire,own(348))),
 BuiltinConditions.spell('bolt',686),
 BuiltinConditions.spell('tap',1454,health('GREATERTHAN',.4)),
 BuiltinConditions.stop('exhausted'),
}}))
-- Armor: Fel Armor (62) over Demon Armor (20) over Demon Skin. A learned better armor
-- replaces Skin but never Demon Armor the player chose, and an unready preferred armor
-- never licenses a fallback. Unreadable learning or auras stay unavailable.
local function missing(id)return BuiltinConditions.negate(buff(id,true))end
assert(addon:RegisterDefaultBlock({id='tbc.warlock.armor',revision=1,families={'tbc'},class='WARLOCK',steps={
 BuiltinConditions.spell('fel-armor',28176,BuiltinConditions.all(BuiltinConditions.known(28176),missing(28176),missing(706))),
 BuiltinConditions.spell('armor',706,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(28176)),BuiltinConditions.known(706),missing(706),missing(28176))),
 BuiltinConditions.spell('skin',687,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(28176)),BuiltinConditions.negate(BuiltinConditions.known(706)),missing(706),missing(687),missing(28176))),
}}))
-- Pet and talent upkeep. Summons are out of combat; a sacrificed demon is not resummoned.
local sacrificed={type='OR',value={buff(18789),buff(18790),buff(18791),buff(18792),buff(35701)}}
local summon=BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate({type='PET'}),BuiltinConditions.negate(sacrificed))
assert(addon:RegisterDefaultBlock({id='tbc.warlock.upkeep',revision=1,families={'tbc'},class='WARLOCK',steps={
 BuiltinConditions.spell('felguard',30146,summon),
 BuiltinConditions.spell('voidwalker',697,BuiltinConditions.all(summon,BuiltinConditions.negate(group()),BuiltinConditions.negate(BuiltinConditions.known(30146)))),
 BuiltinConditions.spell('imp',688,BuiltinConditions.all(summon,BuiltinConditions.negate(BuiltinConditions.known(30146)),BuiltinConditions.any(group(),BuiltinConditions.negate(BuiltinConditions.known(697))))),
 BuiltinConditions.spell('sacrifice',18788,BuiltinConditions.all({type='PET'},BuiltinConditions.negate(sacrificed),BuiltinConditions.negate(BuiltinConditions.known(30146)),BuiltinConditions.negate(BuiltinConditions.known(19028)))),
 BuiltinConditions.spell('soul-link',19028,BuiltinConditions.all({type='PET'},BuiltinConditions.negate(buff(25228)))),
 BuiltinConditions.spell('amplify',18288,BuiltinConditions.all(BuiltinConditions.combat(),{type='ATTACKABLE',unit='target'},BuiltinConditions.negate(ownCurse()))),
 BuiltinConditions.spell('soulshatter',29858,BuiltinConditions.all(group(),{type='THREAT',unit='target',threat=2})),
}}))
