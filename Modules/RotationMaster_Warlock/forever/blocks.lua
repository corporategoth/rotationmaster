-- Copyright 2018-2026 Preston A. Elder <prez@neuromancy.net>. Released under a modified MIT license (MIT + Attribution); see the LICENSE file for details.

-- Shared WoW Forever Warlock blocks (Built In composition; authoring-time only).
-- Consumers: rm.forever.warlock.dps, .dps.icyveins and .dps.wowhead. A content change needs a
-- block revision bump, every consumer's pin and revision bumped, and both recorded in
-- tests/fixtures/builtin_composition_ledger.lua.
-- Policy and sources are the consumers'; see premade-research forever/warlock.md.
-- RM cannot read Forever talents, so trees are told apart by talent-taught actives: Conflagrate
-- (Destruction, 16 points), Fel Domination (Demonology, 16), Incinerate stands in for Shadow
-- and Flame 5/5. IDs are beta data; verify in game.
local _,addon=...
local BuiltinConditions=addon.BuiltInConditionHelpers
local function buff(id)return{type='BUFF',unit='player',spell=id,anyrank=true}end
local function own(id)return{type='DEBUFF',unit='target',spell=id,anyrank=true,owndebuff=true}end
local function shards(op,v)return{type='CARRYING',item={6265},operator=op,value=v}end
local function item(id,items,conditions)return{id=id,type='item',action=items,conditions=conditions}end
local function fire()return BuiltinConditions.any(BuiltinConditions.known(1293817),BuiltinConditions.known(412758))end
local firestones,spellstones={13701,13700,13699,1254},{13603,13602,5522}
-- Demonic Sacrifice buffs (renamed in Forever); keep them only with Demonic Pact, whose proxy is
-- Soul Link known at 40+ (Pact is passive).
local function sacrificed()return BuiltinConditions.any(buff(18789),buff(18790),buff(18791),buff(18792))end
local function pact()return BuiltinConditions.all(BuiltinConditions.known(19028),{type='LEVEL',unit='player',operator='GREATERTHANOREQUALS',value=40})end
-- Manual casts and channels (Drain Life, Drain Soul, Wrack, Hellfire, Rain of Fire, Health
-- Funnel) run to the end; no advice against a target that is not yours to pull.
assert(addon:RegisterDefaultBlock({id='forever.warlock.boundaries',revision=3,families={'forever'},class='WARLOCK',steps={
 BuiltinConditions.stop('cast',BuiltinConditions.any({type='CASTING',unit='player'},{type='CHANNELING',unit='player'},BuiltinConditions.negate(BuiltinConditions.all({type='ATTACKABLE',unit='target'},BuiltinConditions.any(BuiltinConditions.combat(),BuiltinConditions.negate({type='COMBAT',unit='target'})))))),
}}))
-- Independent reminders every source shares: armor, Soul Link, the Demonology sacrifice with
-- Pact, and the weapon stone (Firestone for a Fire build, else Spellstone). Health is secret on
-- Forever, so Health Funnel is the player's call.
assert(addon:RegisterDefaultBlock({id='forever.warlock.upkeep',revision=2,families={'forever'},class='WARLOCK',steps={
 BuiltinConditions.spell('demon-armor',706,BuiltinConditions.negate(BuiltinConditions.any(buff(706),buff(687)))),
 BuiltinConditions.spell('demon-skin',687,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.known(706)),BuiltinConditions.negate(BuiltinConditions.any(buff(706),buff(687))))),
 BuiltinConditions.spell('fel-domination',18708,BuiltinConditions.all(BuiltinConditions.combat(),BuiltinConditions.negate({type='PET'}),BuiltinConditions.any(BuiltinConditions.negate(sacrificed()),pact()))),
 BuiltinConditions.spell('demonic-sacrifice',18788,BuiltinConditions.all({type='PET'},pact(),BuiltinConditions.negate(sacrificed()))),
 BuiltinConditions.spell('soul-link',19028,BuiltinConditions.all({type='PET'},BuiltinConditions.negate(buff(25228)))),
 item('firestone',firestones,BuiltinConditions.all(BuiltinConditions.negate({type='WEAPON'}),fire())),
 item('spellstone',spellstones,BuiltinConditions.all(BuiltinConditions.negate({type='WEAPON'}),BuiltinConditions.negate(fire()))),
 BuiltinConditions.spell('create-firestone',6366,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),fire(),{type='CARRYING',item=firestones,operator='LESSTHAN',value=1})),
 BuiltinConditions.spell('create-spellstone',2362,BuiltinConditions.all(BuiltinConditions.negate(BuiltinConditions.combat()),BuiltinConditions.negate(fire()),{type='CARRYING',item=spellstones,operator='LESSTHAN',value=1})),
}}))
-- Procs expire, so first: Nightfall's Shadow Trance (instant Shadow Bolt) and Decimation (Soul
-- Fire). Then the Demonology core: keep Demonic Brand on the target with Searing Pain.
assert(addon:RegisterDefaultBlock({id='forever.warlock.procs',revision=1,families={'forever'},class='WARLOCK',steps={
 BuiltinConditions.spell('shadow-trance',686,buff(17941)),
 BuiltinConditions.spell('decimation',6353,buff(440873)),
 BuiltinConditions.spell('demonic-brand',5676,BuiltinConditions.all(BuiltinConditions.any(BuiltinConditions.known(1293695),BuiltinConditions.known(18708)),BuiltinConditions.negate(own(1293696)))),
}}))
-- Moving: instants only, then stop. Corruption is left out because RM cannot see whether
-- Improved Corruption has made it instant.
assert(addon:RegisterDefaultBlock({id='forever.warlock.moving',revision=3,families={'forever'},class='WARLOCK',steps={
 {id='moving',type='branch',conditions={type='MOVING'},onFalse={},onTrue={
  BuiltinConditions.spell('moving-agony',980,BuiltinConditions.all(BuiltinConditions.negate(own(980)),BuiltinConditions.negate(own(603)),BuiltinConditions.negate(own(1324473)))),
  BuiltinConditions.spell('moving-siphon',18265,BuiltinConditions.negate(own(18265))),
  BuiltinConditions.spell('moving-conflagrate',1293817,own(348)),
  BuiltinConditions.spell('moving-shadowburn',17877,shards('GREATERTHANOREQUALS',2)),
  BuiltinConditions.stop('moving-stop'),
 }},
}}))
-- Three or more engaged enemies: Hellfire in a group (health is secret on Forever, so watch your
-- own), Rain of Fire, and
-- Corruption and Agony on the current target; the single-target priority then continues.
assert(addon:RegisterDefaultBlock({id='forever.warlock.aoe',revision=2,families={'forever'},class='WARLOCK',steps={
 {id='aoe',type='branch',conditions={type='THREAT_COUNT',threat=1,operator='GREATERTHANOREQUALS',value=3},onFalse={},onTrue={
  BuiltinConditions.spell('hellfire',1949,{type='GROUP'}),
  BuiltinConditions.spell('rain-of-fire',5740),
  BuiltinConditions.spell('aoe-corruption',172,BuiltinConditions.negate(own(172))),
  BuiltinConditions.spell('aoe-agony',980,BuiltinConditions.all(BuiltinConditions.negate(own(980)),BuiltinConditions.negate(own(603)),BuiltinConditions.negate(own(1324473)))),
 }},
}}))
-- Solo wand filler: keep an active wand going rather than suggesting a spell over it.
assert(addon:RegisterDefaultBlock({id='forever.warlock.wand',revision=2,families={'forever'},class='WARLOCK',steps={
 BuiltinConditions.stop('wanding',{type='SPELL_AUTOREPEAT',spell=5019}),
 BuiltinConditions.spell('wand',5019),
}}))
